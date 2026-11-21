-- 공식 Q01~Q12: 미션 2 안내문 기준
-- 파라미터 표기 @변수는 MySQL Workbench에서 SET으로 설정한 뒤 실행.
USE pbl_db;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci; -- 세션 collation을 테이블(utf8mb4_unicode_ci)과 맞춰 사용자 변수 비교 오류(1267) 방지

-- Q01 특정 학생 기본정보 (조회 권한 검사 포함).
-- 입력: SET @student_no='20240001'; SET @requester_user_id=<조회 요청자 user_id>;
-- fn_can_view_student(01_schema.sql, role_policy 기반): 학생=본인(OWN)만, 일반/최고관리자=전체(ALL), 그 외 0행.
SET @student_no='20240001';
SET @requester_user_id=(SELECT user_id FROM user_account WHERE login_id='admin01'); -- 예: 학생 본인이면 'student01'
SELECT s.student_no,u.user_name,u.email,s.college,s.department,s.major_type,s.campus,s.grade,
       s.academic_status,s.admission_type,s.admission_date,s.phone
FROM student s JOIN user_account u ON u.user_id=s.user_id
WHERE s.student_no=@student_no
  AND fn_can_view_student(@requester_user_id,s.student_no)=1;

-- Q02 학생정보 수정 요청 및 처리 이력. 입력: SET @student_no='20240001';
SELECT s.student_no,u.user_name,r.requested_field,r.old_value,r.new_value,r.request_status,
       a.user_name AS processor,r.requested_at,r.processed_at,r.process_comment
FROM student_change_request r JOIN student s ON s.student_id=r.student_id
JOIN user_account u ON u.user_id=s.user_id
LEFT JOIN user_account a ON a.user_id=r.processed_by
WHERE s.student_no=@student_no ORDER BY r.requested_at,r.request_id;

-- Q03 학생별 TOPCIT 점수와 이전 응시 회차 대비 변화.
SELECT s.student_no,u.user_name,e.exam_round,e.exam_date,ts.score,
       ts.score-LAG(ts.score) OVER(PARTITION BY s.student_id ORDER BY e.exam_date,e.exam_id) AS score_change
FROM topcit_score ts JOIN student s ON s.student_id=ts.student_id
JOIN user_account u ON u.user_id=s.user_id JOIN topcit_exam e ON e.exam_id=ts.exam_id
WHERE s.student_no=@student_no ORDER BY e.exam_date;

-- Q04 회차·학과·학년별 평균 및 응시자 수.
SELECT e.exam_round,s.department,s.grade,COUNT(*) AS examinee_count,ROUND(AVG(ts.score),1) AS average_score
FROM topcit_score ts JOIN student s ON s.student_id=ts.student_id JOIN topcit_exam e ON e.exam_id=ts.exam_id
GROUP BY e.exam_id,e.exam_round,s.department,s.grade
ORDER BY e.exam_date,s.department,s.grade;

-- Q05 학생별 누적 마일리지. 승인만 합산하고 미적립 학생도 0으로 표시.
SELECT s.student_no,u.user_name,COALESCE(SUM(CASE WHEN ma.application_status='APPROVED' THEN p.mileage_points ELSE 0 END),0) AS total_mileage
FROM student s JOIN user_account u ON u.user_id=s.user_id
LEFT JOIN mileage_application ma ON ma.student_id=s.student_id
LEFT JOIN program p ON p.program_id=ma.program_id
GROUP BY s.student_id,s.student_no,u.user_name ORDER BY s.student_no;

-- Q06 프로그램·기간별 승인 마일리지 내역 및 합계. 기간 기준은 신청 처리일이 아니라 신청일.
SET @program_id=1; SET @date_from='2026-03-01'; SET @date_to='2026-12-31';
SELECT p.program_name,ma.applied_at,s.student_no,u.user_name,p.mileage_points,ma.application_status,
       ma.processed_at
FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id
JOIN student s ON s.student_id=ma.student_id JOIN user_account u ON u.user_id=s.user_id
WHERE ma.program_id=@program_id AND ma.application_status='APPROVED'
  AND ma.applied_at >= @date_from AND ma.applied_at < DATE_ADD(@date_to,INTERVAL 1 DAY)
ORDER BY ma.applied_at;
SELECT p.program_name,COUNT(*) AS approved_count,COALESCE(SUM(p.mileage_points),0) AS approved_mileage_total
FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id
WHERE ma.program_id=@program_id AND ma.application_status='APPROVED'
  AND ma.applied_at >= @date_from AND ma.applied_at < DATE_ADD(@date_to,INTERVAL 1 DAY)
GROUP BY p.program_id,p.program_name;

-- Q07 관리자용 대기 마일리지 신청 목록 + 증빙 메타데이터.
SELECT ma.application_id,s.student_no,u.user_name,p.program_name,p.mileage_points,ma.applied_at,
       ma.evidence_file_name,ma.evidence_location
FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id
JOIN user_account u ON u.user_id=s.user_id JOIN program p ON p.program_id=ma.program_id
WHERE ma.application_status='PENDING' ORDER BY ma.applied_at;

-- Q08 사업·예산항목별 예산, 승인 지출, 잔액, 집행률. LEFT JOIN으로 무지출 항목 포함.
SELECT bp.project_name,c.category_name,b.amount AS budget_amount,
       COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0) AS approved_spend,
       b.amount-COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0) AS balance,
       CASE WHEN b.amount=0 THEN 0
            ELSE ROUND(100*COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0)/b.amount,2)
       END AS execution_rate_pct
FROM budget b JOIN budget_project bp ON bp.project_id=b.project_id
JOIN category c ON c.category_id=b.category_id
LEFT JOIN expenditure e ON e.budget_id=b.budget_id
GROUP BY b.budget_id,bp.project_name,c.category_name,b.amount
ORDER BY bp.project_name,c.category_name;

-- Q09 교수별·지출 주체별 승인 지출 합계.
SELECT pr.professor_name,e.spending_entity,SUM(e.amount) AS approved_spend,COUNT(*) AS approved_count
FROM expenditure e JOIN professor pr ON pr.professor_id=e.professor_id
WHERE e.status='APPROVED'
GROUP BY pr.professor_id,pr.professor_name,e.spending_entity
ORDER BY pr.professor_name,e.spending_entity;

-- Q10 프로그램(사업)별·문항별 만족도 평균/응답 수. 완료 응답은 모든 문항 답변이 존재하는 응답.
WITH completed AS (
  SELECT r.response_id,r.survey_id,r.student_id
  FROM survey_response r JOIN survey_question q ON q.survey_id=r.survey_id
  LEFT JOIN survey_answer a ON a.response_id=r.response_id AND a.question_id=q.question_id
  GROUP BY r.response_id,r.survey_id,r.student_id
  HAVING COUNT(q.question_id)=COUNT(a.answer_id)
)
SELECT bp.project_name,sv.title,q.question_text,q.question_type,
       ROUND(AVG(CASE WHEN q.question_type='SCORE' THEN a.score END),2) AS average_score,
       COUNT(CASE WHEN q.question_type='SCORE' THEN a.score END) AS numeric_response_count,
       COUNT(CASE WHEN q.question_type='TEXT' THEN a.answer_text END) AS text_response_count
FROM completed cr JOIN survey sv ON sv.survey_id=cr.survey_id
JOIN budget_project bp ON bp.project_id=sv.project_id
JOIN survey_question q ON q.survey_id=sv.survey_id
LEFT JOIN survey_answer a ON a.response_id=cr.response_id AND a.question_id=q.question_id
GROUP BY bp.project_name,sv.survey_id,sv.title,q.question_id,q.question_text,q.question_type
ORDER BY bp.project_name,sv.title,q.display_order;

-- Q11 학과·학년별 숫자형 만족도와 주관식 의견 분리. 이름/학번 대신 집계 및 익명 의견.
SELECT s.department,s.grade,sv.title,q.question_text,
       ROUND(AVG(a.score),2) AS average_score,COUNT(a.score) AS response_count
FROM survey_response r JOIN student s ON s.student_id=r.student_id
JOIN survey sv ON sv.survey_id=r.survey_id
JOIN survey_question q ON q.survey_id=sv.survey_id AND q.question_type='SCORE'
JOIN survey_answer a ON a.response_id=r.response_id AND a.question_id=q.question_id
GROUP BY s.department,s.grade,sv.survey_id,sv.title,q.question_id,q.question_text
ORDER BY s.department,s.grade,sv.title,q.display_order;

SELECT s.department,s.grade,sv.title,q.question_text,a.answer_text
FROM survey_response r JOIN student s ON s.student_id=r.student_id
JOIN survey sv ON sv.survey_id=r.survey_id
JOIN survey_question q ON q.survey_id=sv.survey_id AND q.question_type='TEXT'
JOIN survey_answer a ON a.response_id=r.response_id AND a.question_id=q.question_id
ORDER BY s.department,s.grade,sv.title,q.display_order;

-- Q12 변경/승인 로그. 선택적 조건: SET @target_type='expenditure'; 또는 NULL 전체 조회.
SET @target_type=NULL; SET @target_id=NULL;
SELECT l.target_type,l.target_id,l.action_type,u.user_name AS processor,l.created_at,l.change_detail
FROM change_log l LEFT JOIN user_account u ON u.user_id=l.actor_user_id
WHERE (@target_type IS NULL OR l.target_type=@target_type)
  AND (@target_id IS NULL OR l.target_id=@target_id)
ORDER BY l.created_at DESC,l.log_id DESC;
