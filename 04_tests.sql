-- =====================================================================
-- 04_tests.sql : 오류 입력 / 상태 변경 / 승인·집계 / 롤백 / 접근통제 검증
-- DBMS: MySQL 8.0.16+ (CHECK 제약 필요)
--
-- [실행 순서]  01_schema.sql -> 02_seed.sql -> (03_queries.sql) -> 04_tests.sql
-- [재실행]     이 스크립트는 승인 처리 등으로 데이터를 "변경"한다. 다시 돌리려면
--              DROP DATABASE pbl_db; 후 01 -> 02 -> 04 순서로 다시 실행.
--              (시작부의 P 사전조건 검증이 FAIL이면 DB가 초기 상태가 아니라는 뜻)
-- [실행 예]    docker exec -i mysql-pbl mysql -uroot -ppw --default-character-set=utf8mb4 --table -e "source /sql/04_tests.sql"
--
-- [동작 방식]
--  * 오류 테스트는 t_expect_error()가 prepared statement로 실행하고 오류번호(errno)/메시지를 잡아
--    기대값과 비교한다. 따라서 오류가 나도 스크립트가 중단되지 않고 끝까지 실행되며,
--    마지막에 PASS / FAIL / GAP 표가 출력된다.
--  * 결과 상태: PASS=기대와 일치, FAIL=불일치, GAP=설계상 DB가 강제하지 않는 한계(미구현 범위로 보고서에 명시),
--               INFO=참고 설명
--
-- [오류별 개별 실행]  각 CALL t_expect_error(...) 의 4번째 인자(큰따옴표 안의 SQL)를 그대로
--                    복사해 단독 실행하면 DBMS 원본 오류 메시지를 화면으로 캡처할 수 있다.
--                    (필요한 @변수는 "SETUP" 블록을 먼저 실행해 두어야 함)
--
-- [구현 방식 구분]  (미션 §8 요구)
--  1) DB가 자동 강제: PK/FK/UNIQUE/NOT NULL/CHECK/ENUM  -> A 섹션
--  2) 프로시저(트랜잭션+상태전이+역할검사+예산한도) : process_* 3종 -> B~E 섹션
--  3) 검증 SQL(집계 결과를 수작업 예상값과 대조)               -> P, C~F 섹션의 t_check
--  4) 미구현/한계: DB 계정(GRANT)·행 단위 보안 미사용, 일부 설문 무결성 -> G 섹션의 GAP/INFO
-- =====================================================================
USE pbl_db;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================================
-- SETUP-1. 결과 저장용 임시 테이블 + 검증 도우미 프로시저
-- =====================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_test_result;
CREATE TEMPORARY TABLE tmp_test_result (
  seq INT AUTO_INCREMENT PRIMARY KEY,
  test_id VARCHAR(10), category VARCHAR(40), description VARCHAR(255),
  expected VARCHAR(255), actual VARCHAR(255), result VARCHAR(10)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER $$

DROP PROCEDURE IF EXISTS t_record$$
CREATE PROCEDURE t_record(IN p_id VARCHAR(10), IN p_cat VARCHAR(40), IN p_desc VARCHAR(255),
                          IN p_exp VARCHAR(255), IN p_act VARCHAR(255), IN p_result VARCHAR(10))
BEGIN
  INSERT INTO tmp_test_result(test_id,category,description,expected,actual,result)
  VALUES (p_id,p_cat,p_desc,p_exp,p_act,p_result);
END$$

-- 오류가 나야 하는 SQL: errno(+메시지 패턴)가 기대와 같으면 PASS
DROP PROCEDURE IF EXISTS t_expect_error$$
CREATE PROCEDURE t_expect_error(IN p_id VARCHAR(10), IN p_cat VARCHAR(40), IN p_desc VARCHAR(255),
                                IN p_sql TEXT, IN p_errno INT, IN p_msg_like VARCHAR(200))
BEGIN
  DECLARE v_errno INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
  -- strict 모드의 ENUM/잘림 오류(1265)는 SQLSTATE 01000(경고 클래스)로 올라오므로 별도 핸들러 필요
  DECLARE CONTINUE HANDLER FOR SQLWARNING
  BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
  SET @t_sql = p_sql;
  PREPARE st FROM @t_sql; EXECUTE st; DEALLOCATE PREPARE st;
  CALL t_record(p_id,p_cat,p_desc,
    CONCAT('errno=',p_errno,IF(p_msg_like='%','',CONCAT(' / ',p_msg_like))),
    CONCAT('errno=',v_errno,IF(v_msg='','',CONCAT(' / ',LEFT(v_msg,110)))),
    IF(v_errno=p_errno AND v_msg LIKE p_msg_like,'PASS','FAIL'));
END$$

-- 성공해야 하는 SQL(경계값 허용 등)
DROP PROCEDURE IF EXISTS t_expect_ok$$
CREATE PROCEDURE t_expect_ok(IN p_id VARCHAR(10), IN p_cat VARCHAR(40), IN p_desc VARCHAR(255), IN p_sql TEXT)
BEGIN
  DECLARE v_errno INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
  SET @t_sql = p_sql;
  PREPARE st FROM @t_sql; EXECUTE st; DEALLOCATE PREPARE st;
  CALL t_record(p_id,p_cat,p_desc,'success',
    IF(v_errno=0,'success',CONCAT('errno=',v_errno,' / ',LEFT(v_msg,110))),
    IF(v_errno=0,'PASS','FAIL'));
END$$

-- 스칼라 조회 결과(1행 1열)를 기대 문자열과 비교. NULL은 'NULL'로 비교.
DROP PROCEDURE IF EXISTS t_check$$
CREATE PROCEDURE t_check(IN p_id VARCHAR(10), IN p_cat VARCHAR(40), IN p_desc VARCHAR(255),
                         IN p_expected VARCHAR(255), IN p_query TEXT)
BEGIN
  DECLARE v_errno INT DEFAULT 0;
  DECLARE v_msg TEXT DEFAULT '';
  DECLARE v_act VARCHAR(255);
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
  SET @t_actual = NULL;
  SET @t_sql = CONCAT('SELECT (',p_query,') INTO @t_actual');
  PREPARE st FROM @t_sql; EXECUTE st; DEALLOCATE PREPARE st;
  IF v_errno<>0 THEN SET v_act = CONCAT('ERROR ',v_errno,': ',LEFT(v_msg,150));
  ELSE SET v_act = COALESCE(CAST(@t_actual AS CHAR),'NULL'); END IF;
  CALL t_record(p_id,p_cat,p_desc,p_expected,v_act,IF(v_act=p_expected,'PASS','FAIL'));
END$$

-- "DB가 막아야 하지만 현재 스키마는 막지 않는" 한계 확인용: 수락되면 GAP
DROP PROCEDURE IF EXISTS t_gap$$
CREATE PROCEDURE t_gap(IN p_id VARCHAR(10), IN p_cat VARCHAR(40), IN p_desc VARCHAR(255),
                       IN p_sql TEXT, IN p_note VARCHAR(200))
BEGIN
  DECLARE v_errno INT DEFAULT 0;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO; END;
  SET @t_sql = p_sql;
  PREPARE st FROM @t_sql; EXECUTE st; DEALLOCATE PREPARE st;
  CALL t_record(p_id,p_cat,p_desc,'거부되어야 함',
    IF(v_errno=0,CONCAT('수락됨(미강제): ',p_note),CONCAT('거부 errno=',v_errno)),
    IF(v_errno=0,'GAP','PASS'));
END$$

-- fn_can_view_student()는 01_schema.sql(role_policy 기반)의 정의를 그대로 사용한다. 여기서 재정의하지 않는다.

DELIMITER ;

-- =====================================================================
-- SETUP-2. ID 조회용 변수 및 03_queries.sql의 Q 쿼리 복사본(실제 쿼리로 검증하기 위함)
--  ※ 03의 Q 쿼리를 수정하면 아래 복사본도 같이 수정할 것.
-- =====================================================================
SELECT user_id INTO @u_admin1 FROM user_account WHERE login_id='admin01'; -- 일반관리자
SELECT user_id INTO @u_admin2 FROM user_account WHERE login_id='admin02'; -- 최고관리자
SELECT user_id INTO @u_stu1   FROM user_account WHERE login_id='student01';
SELECT user_id INTO @u_prof1  FROM user_account WHERE login_id='prof01';
SELECT student_id INTO @sid1 FROM student WHERE student_no='20240001';
SELECT student_id INTO @sid2 FROM student WHERE student_no='20240002';
SELECT student_id INTO @sid6 FROM student WHERE student_no='20240006';
SELECT professor_id INTO @prof_kim FROM professor WHERE professor_name='김교수';

SELECT b.budget_id INTO @bud_equip FROM budget b JOIN budget_project p ON p.project_id=b.project_id
 JOIN category c ON c.category_id=b.category_id WHERE p.project_name='2026년 SW중심대학 사업' AND c.category_name='장비구입비';
SELECT b.budget_id INTO @bud_ops FROM budget b JOIN budget_project p ON p.project_id=b.project_id
 JOIN category c ON c.category_id=b.category_id WHERE p.project_name='2026년 SW중심대학 사업' AND c.category_name='운영비';
SELECT b.budget_id INTO @bud_stu FROM budget b JOIN budget_project p ON p.project_id=b.project_id
 JOIN category c ON c.category_id=b.category_id WHERE p.project_name='2026년 SW중심대학 사업' AND c.category_name='학생인건비';

SELECT request_id INTO @req_s1 FROM student_change_request WHERE student_id=@sid1 AND request_status='PENDING';
SELECT r.request_id INTO @req_s4 FROM student_change_request r JOIN student s ON s.student_id=r.student_id
 WHERE s.student_no='20240004' AND r.request_status='PENDING';
SELECT ma.application_id INTO @app_s2 FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id WHERE s.student_no='20240002';
SELECT ma.application_id INTO @app_s5 FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id WHERE s.student_no='20240005';
SELECT ma.application_id INTO @app_s7 FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id WHERE s.student_no='20240007';
SELECT ma.application_id INTO @app_s10 FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id WHERE s.student_no='20240010';
SELECT expenditure_id INTO @exp_equip FROM expenditure WHERE description='장비 구매 대기';
SELECT expenditure_id INTO @exp_glob  FROM expenditure WHERE description='인건비 대기';
SELECT expenditure_id INTO @exp_stu   FROM expenditure WHERE description='승인 대기 학생 인건비';

SELECT survey_id INTO @sv1 FROM survey WHERE title='SW사업 만족도 조사';
SELECT survey_id INTO @sv2 FROM survey WHERE title='글로벌 인재양성 만족도 조사';
SELECT question_id INTO @q1 FROM survey_question WHERE survey_id=@sv1 AND display_order=1;
SELECT question_id INTO @q2 FROM survey_question WHERE survey_id=@sv1 AND display_order=2;
SELECT question_id INTO @q3 FROM survey_question WHERE survey_id=@sv1 AND display_order=3;
SELECT question_id INTO @q_g1 FROM survey_question WHERE survey_id=@sv2 AND display_order=1;

SET @student_no='20240001';
SET @requester_user_id=@u_admin1; -- Q01 기본 요청자: 일반관리자
SET @target_type=NULL; SET @target_id=NULL;

SET @q01 = "SELECT s.student_no,u.user_name,u.email,s.college,s.department,s.major_type,s.campus,s.grade,
       s.academic_status,s.admission_type,s.admission_date,s.phone
FROM student s JOIN user_account u ON u.user_id=s.user_id WHERE s.student_no=@student_no
  AND fn_can_view_student(@requester_user_id,s.student_no)=1";
SET @q02 = "SELECT s.student_no,u.user_name,r.requested_field,r.old_value,r.new_value,r.request_status,
       a.user_name AS processor,r.requested_at,r.processed_at,r.process_comment
FROM student_change_request r JOIN student s ON s.student_id=r.student_id
JOIN user_account u ON u.user_id=s.user_id LEFT JOIN user_account a ON a.user_id=r.processed_by
WHERE s.student_no=@student_no";
SET @q03 = "SELECT s.student_no,u.user_name,e.exam_round,e.exam_date,ts.score,
       ts.score-LAG(ts.score) OVER(PARTITION BY s.student_id ORDER BY e.exam_date,e.exam_id) AS score_change
FROM topcit_score ts JOIN student s ON s.student_id=ts.student_id
JOIN user_account u ON u.user_id=s.user_id JOIN topcit_exam e ON e.exam_id=ts.exam_id
WHERE s.student_no=@student_no";
SET @q04 = "SELECT e.exam_round,s.department,s.grade,COUNT(*) AS examinee_count,ROUND(AVG(ts.score),1) AS average_score
FROM topcit_score ts JOIN student s ON s.student_id=ts.student_id JOIN topcit_exam e ON e.exam_id=ts.exam_id
GROUP BY e.exam_id,e.exam_round,s.department,s.grade";
SET @q05 = "SELECT s.student_no,u.user_name,COALESCE(SUM(CASE WHEN ma.application_status='APPROVED' THEN p.mileage_points ELSE 0 END),0) AS total_mileage
FROM student s JOIN user_account u ON u.user_id=s.user_id
LEFT JOIN mileage_application ma ON ma.student_id=s.student_id
LEFT JOIN program p ON p.program_id=ma.program_id
GROUP BY s.student_id,s.student_no,u.user_name";
SET @q07 = "SELECT ma.application_id,s.student_no,u.user_name,p.program_name,p.mileage_points,ma.applied_at,
       ma.evidence_file_name,ma.evidence_location
FROM mileage_application ma JOIN student s ON s.student_id=ma.student_id
JOIN user_account u ON u.user_id=s.user_id JOIN program p ON p.program_id=ma.program_id
WHERE ma.application_status='PENDING'";
SET @q08 = "SELECT bp.project_name,c.category_name,b.amount AS budget_amount,
       COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0) AS approved_spend,
       b.amount-COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0) AS balance,
       CASE WHEN b.amount=0 THEN 0
            ELSE ROUND(100*COALESCE(SUM(CASE WHEN e.status='APPROVED' THEN e.amount ELSE 0 END),0)/b.amount,2)
       END AS execution_rate_pct
FROM budget b JOIN budget_project bp ON bp.project_id=b.project_id
JOIN category c ON c.category_id=b.category_id
LEFT JOIN expenditure e ON e.budget_id=b.budget_id
GROUP BY b.budget_id,bp.project_name,c.category_name,b.amount";
SET @q09 = "SELECT pr.professor_name,e.spending_entity,SUM(e.amount) AS approved_spend,COUNT(*) AS approved_count
FROM expenditure e JOIN professor pr ON pr.professor_id=e.professor_id
WHERE e.status='APPROVED' GROUP BY pr.professor_id,pr.professor_name,e.spending_entity";
SET @q10 = "WITH completed AS (
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
GROUP BY bp.project_name,sv.survey_id,sv.title,q.question_id,q.question_text,q.question_type";
SET @q12 = "SELECT l.target_type,l.target_id,l.action_type,u.user_name AS processor,l.created_at,l.change_detail
FROM change_log l LEFT JOIN user_account u ON u.user_id=l.actor_user_id
WHERE (@target_type IS NULL OR l.target_type=@target_type)
  AND (@target_id IS NULL OR l.target_id=@target_id)";

-- =====================================================================
-- P. 사전조건(초기 시드 상태) + 정상 집계의 수작업 예상값 대조 (미션 §6)
-- =====================================================================
CALL t_check('P01','P.사전조건','학생 수','10',"SELECT COUNT(*) FROM student");
CALL t_check('P02','P.사전조건','TOPCIT 점수 건수(2회차 x 10명)','20',"SELECT COUNT(*) FROM topcit_score");
CALL t_check('P03','P.사전조건','프로그램/마일리지 신청 건수','3/10',"SELECT CONCAT((SELECT COUNT(*) FROM program),'/',(SELECT COUNT(*) FROM mileage_application))");
CALL t_check('P04','P.사전조건','예산항목 7개, 지출 10건','7/10',"SELECT CONCAT((SELECT COUNT(*) FROM category),'/',(SELECT COUNT(*) FROM expenditure))");
CALL t_check('P05','P.사전조건','설문/문항/응답/답변 건수','2/6/10/30',"SELECT CONCAT((SELECT COUNT(*) FROM survey),'/',(SELECT COUNT(*) FROM survey_question),'/',(SELECT COUNT(*) FROM survey_response),'/',(SELECT COUNT(*) FROM survey_answer))");
CALL t_check('P06','P.사전조건','승인대기: 변경요청 2 / 마일리지 4 / 지출 3','2/4/3',"SELECT CONCAT((SELECT COUNT(*) FROM student_change_request WHERE request_status='PENDING'),'/',(SELECT COUNT(*) FROM mileage_application WHERE application_status='PENDING'),'/',(SELECT COUNT(*) FROM expenditure WHERE status='PENDING'))");
CALL t_check('P07','P.사전조건','초기 change_log 3건(변경요청 처리 이력)','3',"SELECT COUNT(*) FROM change_log");

-- 수작업 근거: 1번 학생(20240001) 상반기 620, 하반기 700 -> 변화 +80
CALL t_check('S01','S.집계예상값','Q01 학생 1 phone은 승인 전 NULL','NULL',CONCAT("SELECT phone FROM (",@q01,") q"));
CALL t_check('S02','S.집계예상값','Q03 하반기 점수 변화 = 700-620 = 80','80',CONCAT("SELECT score_change FROM (",@q03,") q WHERE exam_round='2025-하반기'"));
-- 수작업 근거: SW학과 1학년 5명 상반기 (620+750+480+810+560)/5 = 3220/5 = 644.0
CALL t_check('S03','S.집계예상값','Q04 2025-상반기 소프트웨어학과 1학년 평균/응시자','644.0/5',CONCAT("SELECT CONCAT(average_score,'/',examinee_count) FROM (",@q04,") q WHERE exam_round='2025-상반기' AND department='소프트웨어학과' AND grade=1"));
-- 수작업 근거: 승인 4건 = 10(1번)+20(4번)+20(6번)+15(9번) = 65, 2번 학생은 미적립 0
CALL t_check('S04','S.집계예상값','Q05 미적립 학생(20240002) 누적 0점 표시','0',CONCAT("SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240002'"));
CALL t_check('S05','S.집계예상값','Q05 전체 승인 마일리지 합계 = 10+20+20+15','65',CONCAT("SELECT SUM(total_mileage) FROM (",@q05,") q"));
-- 수작업 근거: 운영비 예산 1,500,000 중 승인 200,000 -> 잔액 1,300,000, 집행률 13.33%
CALL t_check('S06','S.집계예상값','Q08 운영비 승인지출/잔액/집행률','200000.00/1300000.00/13.33',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='운영비'"));
CALL t_check('S07','S.집계예상값','Q08 승인 지출 없는 여비교통비: 지출 0, 잔액=예산, 집행률 0','0.00/1000000.00/0.00',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='여비교통비'"));
-- 수작업 근거: 박교수 융합 승인 = 4,000,000(글로벌 인건비)+200,000(운영비) = 4,200,000 (대기 1,000,000은 제외)
CALL t_check('S08','S.집계예상값','Q09 박교수/융합 승인지출/건수','4200000.00/2',CONCAT("SELECT CONCAT(approved_spend,'/',approved_count) FROM (",@q09,") q WHERE professor_name='박교수' AND spending_entity='융합'"));
-- 수작업 근거: 학생 1~5의 점수 = 3+MOD(id,3) = 4,5,3,4,5 -> 합 21 / 5 = 4.20
CALL t_check('S09','S.집계예상값','Q10 SW사업 설문 1번 문항 평균/응답수','4.20/5',CONCAT("SELECT CONCAT(average_score,'/',numeric_response_count) FROM (",@q10,") q WHERE title='SW사업 만족도 조사' AND question_text='프로그램 전반에 만족하십니까?'"));
CALL t_check('S10','S.집계예상값','Q10 주관식 문항은 평균 NULL, 의견 수만 집계','NULL/0/5',CONCAT("SELECT CONCAT(COALESCE(average_score,'NULL'),'/',numeric_response_count,'/',text_response_count) FROM (",@q10,") q WHERE title='SW사업 만족도 조사' AND question_text='개선 의견을 작성해 주세요.'"));

-- =====================================================================
-- A. 제약조건 오류 테스트 (DB가 자동 강제)  -- 미션 §7: 1,2,3,4 + 만족도/마일리지 중복
-- =====================================================================
-- 테스트용 임시 TOPCIT 회차(맨 끝 정리 단계에서 삭제). 기존 점수와 UNIQUE가 겹치지 않게 별도 회차 사용.
INSERT INTO topcit_exam(exam_name,exam_date,exam_round) VALUES ('검증용 임시 회차','2099-01-01','T-임시회차');
SET @exam_t = LAST_INSERT_ID();

-- A-1 중복 학번/로그인ID
CALL t_expect_error('A01','A.제약조건','중복 login_id 등록 거부',
 "INSERT INTO user_account(login_id,user_name) VALUES ('student01','중복계정')",1062,'%Duplicate%');
CALL t_check('A02','A.제약조건','기존 student01 계정 1건 그대로 유지','1',"SELECT COUNT(*) FROM user_account WHERE login_id='student01'");
CALL t_expect_error('A03','A.제약조건','중복 학번 등록 거부',
 "INSERT INTO student(user_id,student_no,college,department,major_type,campus,grade,admission_type) SELECT user_id,'20240001','공과대학','소프트웨어학과','공학','천안캠퍼스',1,'신입학' FROM user_account WHERE login_id='admin01'",1062,'%Duplicate%');
CALL t_check('A04','A.제약조건','기존 20240001 학생 정보(김민준) 유지','김민준',"SELECT u.user_name FROM student s JOIN user_account u ON u.user_id=s.user_id WHERE s.student_no='20240001'");
CALL t_expect_error('A05','A.제약조건','NOT NULL: login_id 없이 계정 등록 거부',
 "INSERT INTO user_account(user_name) VALUES ('로그인ID없음')",1364,'%login_id%');

-- A-2 존재하지 않는 FK 참조
CALL t_expect_error('A06','A.FK','존재하지 않는 학생으로 TOPCIT 점수 등록 거부',
 "INSERT INTO topcit_score(student_id,exam_id,score) VALUES (999999,@exam_t,500)",1452,'%foreign key%');
CALL t_expect_error('A07','A.FK','존재하지 않는 프로그램으로 마일리지 신청 거부',
 "INSERT INTO mileage_application(student_id,program_id) VALUES (@sid6,999999)",1452,'%foreign key%');
CALL t_expect_error('A08','A.FK','존재하지 않는 예산항목으로 지출 등록 거부',
 "INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount) VALUES (@prof_kim,999999,'전공',1000)",1452,'%foreign key%');

-- A-3 동일 학생 + 동일 TOPCIT 회차 중복
CALL t_expect_error('A09','A.제약조건','동일 학생+동일 TOPCIT 회차 재등록 거부',
 "INSERT INTO topcit_score(student_id,exam_id,score) SELECT @sid1,exam_id,500 FROM topcit_exam WHERE exam_round='2025-상반기'",1062,'%Duplicate%');
CALL t_check('A10','A.제약조건','기존 점수 620 그대로 유지(덮어쓰기 없음)','1/620',"SELECT CONCAT(COUNT(*),'/',MAX(ts.score)) FROM topcit_score ts JOIN topcit_exam e ON e.exam_id=ts.exam_id WHERE ts.student_id=@sid1 AND e.exam_round='2025-상반기'");

-- A-4 점수 범위(채택 기준: TOPCIT 0~1000) / 경계값
CALL t_expect_error('A11','A.범위','TOPCIT 1200점 거부(상한 초과)',"INSERT INTO topcit_score(student_id,exam_id,score) VALUES (@sid1,@exam_t,1200)",3819,'%chk_topcit_score_range%');
CALL t_expect_error('A12','A.범위','TOPCIT 1001점 거부(상한 바로 위)',"INSERT INTO topcit_score(student_id,exam_id,score) VALUES (@sid1,@exam_t,1001)",3819,'%chk_topcit_score_range%');
CALL t_expect_error('A13','A.범위','TOPCIT -1점 거부(하한 미만)',"INSERT INTO topcit_score(student_id,exam_id,score) VALUES (@sid1,@exam_t,-1)",3819,'%chk_topcit_score_range%');
CALL t_expect_ok('A14','A.범위','TOPCIT 0점 허용(하한 경계)',"INSERT INTO topcit_score(student_id,exam_id,score) VALUES (@sid1,@exam_t,0)");
CALL t_expect_ok('A15','A.범위','TOPCIT 1000점 허용(상한 경계)',"INSERT INTO topcit_score(student_id,exam_id,score) VALUES (@sid2,@exam_t,1000)");

-- A-5 지출 금액 / 학생인건비 규칙
CALL t_expect_error('A16','A.범위','지출 0원 거부',"INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',0,'T-0원')",3819,'%chk_expenditure_positive%');
CALL t_expect_error('A17','A.범위','지출 음수 거부',"INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',-100,'T-음수')",3819,'%chk_expenditure_positive%');
CALL t_expect_ok('A18','A.범위','지출 0.01원 허용(양수 경계, 대기 상태로 등록)',"INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',0.01,'T-경계 0.01')");
CALL t_expect_error('A19','A.제약조건','STUDENT_LABOR인데 학생 없음 거부',"INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,expense_type,description) VALUES (@prof_kim,@bud_stu,'전공',1000,'STUDENT_LABOR','T-학생없음')",3819,'%chk_student_labor%');
CALL t_expect_error('A20','A.제약조건','GENERAL인데 학생 지정 거부',"INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,expense_type,description) VALUES (@prof_kim,@bud_stu,@sid1,'전공',1000,'GENERAL','T-일반+학생')",3819,'%chk_student_labor%');

-- A-6 기타 CHECK / ENUM / UNIQUE
CALL t_expect_error('A21','A.범위','학년 7 거부(1~6)',
 "INSERT INTO student(user_id,student_no,college,department,major_type,campus,grade,admission_type) SELECT user_id,'29999999','공과대학','소프트웨어학과','공학','천안캠퍼스',7,'신입학' FROM user_account WHERE login_id='admin02'",3819,'%chk_student_grade%');
CALL t_expect_error('A22','A.제약조건','잘못된 상태값(ENUM) 거부',"INSERT INTO student_change_request(student_id,requested_field,new_value,request_status) VALUES (@sid1,'phone','010-1','DONE')",1265,'%');
CALL t_expect_error('A23','A.제약조건','마일리지 중복 신청 거부(정책: 학생+프로그램 1회)',
 "INSERT INTO mileage_application(student_id,program_id) SELECT @sid1,program_id FROM program WHERE program_name='AI 기초 특강'",1062,'%Duplicate%');
CALL t_expect_error('A24','A.범위','음수 예산 거부',
 "INSERT INTO budget(project_id,category_id,amount) SELECT p.project_id,c.category_id,-1 FROM budget_project p JOIN category c ON c.category_name='기타' WHERE p.project_name='글로벌 인재양성 사업'",3819,'%chk_budget_amount%');
CALL t_expect_error('A25','A.제약조건','같은 사업+예산항목 중복 등록 거부',
 "INSERT INTO budget(project_id,category_id,amount) SELECT p.project_id,c.category_id,1 FROM budget_project p JOIN category c ON c.category_name='인건비' WHERE p.project_name='2026년 SW중심대학 사업'",1062,'%Duplicate%');
CALL t_expect_error('A26','A.범위','프로그램 마일리지 0점 거부',"INSERT INTO program(program_name,start_date,end_date,mileage_points) VALUES ('T-프로그램','2026-06-01','2026-06-30',0)",3819,'%chk_program_mileage%');
CALL t_expect_error('A27','A.범위','프로그램 종료일 < 시작일 거부',"INSERT INTO program(program_name,start_date,end_date,mileage_points) VALUES ('T-프로그램','2026-06-30','2026-06-01',5)",3819,'%chk_program_dates%');

-- =====================================================================
-- B. 승인 처리 중 실패 -> 롤백 (미션 §7-11, §4 과제4)
--  임시 트리거로 "change_log INSERT"를 강제 실패시킨다. 이 시점에는 업무 테이블 UPDATE가 이미
--  끝난 뒤이므로, 롤백이 안 되면 상태/값이 바뀐 채 남는다 -> 부분 반영 여부를 직접 확인할 수 있다.
-- =====================================================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_t_force_fail$$
CREATE TRIGGER trg_t_force_fail BEFORE INSERT ON change_log FOR EACH ROW
BEGIN
  IF INSTR(NEW.change_detail,'FORCE_FAIL')>0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='강제 실패(롤백 검증용 임시 트리거)';
  END IF;
END$$
DELIMITER ;

-- B-1 학생정보 변경 승인 (student.phone UPDATE + 요청 상태 UPDATE 후 로그 INSERT 실패)
CALL t_expect_error('B01','B.롤백','학생정보 승인 중 로그 기록 실패 -> 오류 전파',
 "CALL process_student_change_request(@req_s4,@u_admin1,'APPROVED','__FORCE_FAIL__')",1644,'%강제 실패%');
CALL t_check('B02','B.롤백','phone|요청상태|처리자|로그수 = 모두 처리 전 상태','NULL|PENDING|NULL|0',
 "SELECT CONCAT(COALESCE(s.phone,'NULL'),'|',r.request_status,'|',COALESCE(r.processed_by,'NULL'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='student_change_request' AND target_id=r.request_id)) FROM student_change_request r JOIN student s ON s.student_id=r.student_id WHERE r.request_id=@req_s4");
-- B-2 마일리지 승인
CALL t_expect_error('B03','B.롤백','마일리지 승인 중 로그 기록 실패 -> 오류 전파',
 "CALL process_mileage_application(@app_s2,@u_admin1,'APPROVED','__FORCE_FAIL__')",1644,'%강제 실패%');
CALL t_check('B04','B.롤백','신청상태|처리자|로그수 = 처리 전 상태','PENDING|NULL|0',
 "SELECT CONCAT(application_status,'|',COALESCE(processed_by,'NULL'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='mileage_application' AND target_id=application_id)) FROM mileage_application WHERE application_id=@app_s2");
CALL t_check('B05','B.롤백','Q05 20240002 누적 마일리지 변동 없음(0)','0',CONCAT("SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240002'"));
-- B-3 지출 승인
CALL t_expect_error('B06','B.롤백','지출 승인 중 로그 기록 실패 -> 오류 전파',
 "CALL process_expenditure(@exp_equip,@u_admin2,'APPROVED','__FORCE_FAIL__')",1644,'%강제 실패%');
CALL t_check('B07','B.롤백','지출상태|처리자|로그수 = 처리 전 상태','PENDING|NULL|0',
 "SELECT CONCAT(status,'|',COALESCE(processed_by,'NULL'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='expenditure' AND target_id=expenditure_id)) FROM expenditure WHERE expenditure_id=@exp_equip");
CALL t_check('B08','B.롤백','Q08 장비구입비 승인지출 변동 없음(1,500,000)','1500000.00',CONCAT("SELECT approved_spend FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='장비구입비'"));

DROP TRIGGER IF EXISTS trg_t_force_fail;

-- =====================================================================
-- C. 학생정보 변경 요청 승인/반려 (미션 §7-5)
-- =====================================================================
CALL t_expect_ok('C01','C.학생정보','관리자(일반관리자)가 phone 변경 요청 승인',"CALL process_student_change_request(@req_s1,@u_admin1,'APPROVED','검증 승인')");
CALL t_check('C02','C.학생정보','승인 후 Q01 기본정보에 phone 반영','010-0000-0001',CONCAT("SELECT phone FROM (",@q01,") q"));
CALL t_check('C03','C.학생정보','Q02 처리 이력: 상태/처리자 확인','APPROVED/일반관리자',CONCAT("SELECT CONCAT(request_status,'/',processor) FROM (",@q02,") q"));
CALL t_check('C04','C.학생정보','승인 로그 1건 기록','1',"SELECT COUNT(*) FROM change_log WHERE target_type='student_change_request' AND target_id=@req_s1 AND action_type='APPROVED'");
CALL t_expect_error('C05','C.학생정보','이미 승인된 요청 재승인 거부(이중 처리 방지)',"CALL process_student_change_request(@req_s1,@u_admin1,'APPROVED','재시도')",1644,'%PENDING%');
CALL t_expect_error('C06','C.학생정보','이미 승인된 요청을 반려로 번복 거부',"CALL process_student_change_request(@req_s1,@u_admin1,'REJECTED','번복')",1644,'%PENDING%');
CALL t_check('C07','C.학생정보','재시도 후에도 phone/로그 수 그대로','010-0000-0001|1',"SELECT CONCAT((SELECT phone FROM student WHERE student_id=@sid1),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='student_change_request' AND target_id=@req_s1))");
CALL t_expect_error('C08','C.학생정보','존재하지 않는 요청 처리 거부',"CALL process_student_change_request(999999,@u_admin1,'APPROVED','x')",1644,'%PENDING%');
CALL t_expect_ok('C09','C.학생정보','phone 변경 요청 반려',"CALL process_student_change_request(@req_s4,@u_admin1,'REJECTED','증빙 부족')");
CALL t_check('C10','C.학생정보','반려 시 기본정보(phone) 유지 | 상태 | 로그수','NULL|REJECTED|1',
 "SELECT CONCAT(COALESCE(s.phone,'NULL'),'|',r.request_status,'|',(SELECT COUNT(*) FROM change_log WHERE target_type='student_change_request' AND target_id=r.request_id)) FROM student_change_request r JOIN student s ON s.student_id=r.student_id WHERE r.request_id=@req_s4");

-- 잘못된 값(학년 9) 요청: 대기 상태로 두고 비관리자/잘못된 decision/잘못된 값 승인 시도
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value)
SELECT student_id,'grade','2','9' FROM student WHERE student_no='20240007';
SET @req_bad = LAST_INSERT_ID();
CALL t_expect_error('C11','C.학생정보','비관리자(학생)의 승인 시도 거부',"CALL process_student_change_request(@req_bad,@u_stu1,'APPROVED','x')",1644,'%관리자%');
CALL t_expect_error('C12','C.학생정보','허용되지 않은 decision 값 거부',"CALL process_student_change_request(@req_bad,@u_admin1,'MAYBE','x')",1644,'%decision%');
CALL t_expect_error('C13','C.학생정보','범위 밖 값(grade=9) 승인 시 거부',"CALL process_student_change_request(@req_bad,@u_admin1,'APPROVED','x')",1644,'%grade%');
CALL t_check('C14','C.학생정보','실패 후 상태|학년|로그수 = 변경 없음','PENDING|2|0',
 "SELECT CONCAT(r.request_status,'|',s.grade,'|',(SELECT COUNT(*) FROM change_log WHERE target_type='student_change_request' AND target_id=r.request_id)) FROM student_change_request r JOIN student s ON s.student_id=r.student_id WHERE r.request_id=@req_bad");

-- =====================================================================
-- D. 마일리지 승인/반려/중복 승인 (미션 §7-6)  ※ 승인 전후 Q05/Q07 비교
-- =====================================================================
CALL t_check('D01','D.마일리지','승인 전 Q07 대기 목록 4건(2,5,7,10번 학생)','4',CONCAT("SELECT COUNT(*) FROM (",@q07,") q"));
CALL t_expect_ok('D02','D.마일리지','20240002 AI 기초 특강 신청 승인',"CALL process_mileage_application(@app_s2,@u_admin1,'APPROVED','참여 확인')");
CALL t_check('D03','D.마일리지','승인 후 Q05: 20240002 누적 0 -> 10','10',CONCAT("SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240002'"));
CALL t_expect_error('D04','D.마일리지','같은 신청 재승인 거부(이중 적립 방지)',"CALL process_mileage_application(@app_s2,@u_admin1,'APPROVED','재시도')",1644,'%중복 승인%');
CALL t_expect_error('D05','D.마일리지','승인된 신청을 반려로 번복 거부',"CALL process_mileage_application(@app_s2,@u_admin1,'REJECTED','번복')",1644,'%PENDING%');
CALL t_check('D06','D.마일리지','재시도 후에도 누적 10점|로그 1건 (한 번만 반영)','10|1',
 CONCAT("SELECT CONCAT((SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240002'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='mileage_application' AND target_id=@app_s2))"));
CALL t_expect_error('D07','D.마일리지','존재하지 않는 신청 처리 거부',"CALL process_mileage_application(999999,@u_admin1,'APPROVED','x')",1644,'%PENDING%');
CALL t_expect_error('D08','D.마일리지','비관리자(학생)의 승인 시도 거부',"CALL process_mileage_application(@app_s10,@u_stu1,'APPROVED','x')",1644,'%관리자%');
CALL t_expect_ok('D09','D.마일리지','20240005 클라우드 워크숍 신청 반려',"CALL process_mileage_application(@app_s5,@u_admin1,'REJECTED','증빙 불충분')");
CALL t_check('D10','D.마일리지','반려 건은 합산 제외: 20240005 누적 0','0',CONCAT("SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240005'"));
CALL t_expect_ok('D11','D.마일리지','20240007 SW 프로젝트 발표회 신청 승인',"CALL process_mileage_application(@app_s7,@u_admin1,'APPROVED','참여 확인')");
CALL t_check('D12','D.마일리지','Q05 20240007 누적 0 -> 15','15',CONCAT("SELECT total_mileage FROM (",@q05,") q WHERE student_no='20240007'"));
-- 수작업 근거: 65(초기) + 10(2번) + 15(7번) = 90 (5번 반려, 10번 대기는 제외)
CALL t_check('D13','D.마일리지','Q05 전체 승인 합계 65 -> 90','90',CONCAT("SELECT SUM(total_mileage) FROM (",@q05,") q"));
CALL t_check('D14','D.마일리지','Q07 대기 목록은 20240010 1건만 남음','1/20240010',CONCAT("SELECT CONCAT(COUNT(*),'/',MAX(student_no)) FROM (",@q07,") q"));
CALL t_check('D15','D.마일리지','프로그램별 승인 건수/합계: AI 기초 특강(1,2번)','2/20',"SELECT CONCAT(COUNT(*),'/',COALESCE(SUM(p.mileage_points),0)) FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id WHERE p.program_name='AI 기초 특강' AND ma.application_status='APPROVED'");
CALL t_check('D16','D.마일리지','프로그램별 승인 건수/합계: 클라우드 실습 워크숍(4,6번)','2/40',"SELECT CONCAT(COUNT(*),'/',COALESCE(SUM(p.mileage_points),0)) FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id WHERE p.program_name='클라우드 실습 워크숍' AND ma.application_status='APPROVED'");
CALL t_check('D17','D.마일리지','프로그램별 승인 건수/합계: SW 프로젝트 발표회(7,9번)','2/30',"SELECT CONCAT(COUNT(*),'/',COALESCE(SUM(p.mileage_points),0)) FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id WHERE p.program_name='SW 프로젝트 발표회' AND ma.application_status='APPROVED'");

-- =====================================================================
-- E. 지출 승인/반려, 예산 한도 (미션 §7-7, §7-8)
--  예산 한도 검증은 CHECK가 아니라 process_expenditure 프로시저(승인 시 SUM 비교)가 수행한다.
--  규칙: (기존 승인 지출 합 + 신규 금액) > 예산 이면 승인 차단. 정확히 같으면 허용.
-- =====================================================================
CALL t_check('E01','E.지출','승인 전 전체 승인 지출 합계','11200000.00',"SELECT SUM(amount) FROM expenditure WHERE status='APPROVED'");
CALL t_expect_ok('E02','E.지출','장비구입비 대기 500,000원 승인(최고관리자)',"CALL process_expenditure(@exp_equip,@u_admin2,'APPROVED','검증 승인')");
-- 수작업 근거: 1,500,000+500,000 = 2,000,000 / 잔액 5,000,000-2,000,000 = 3,000,000 / 집행률 40.00
CALL t_check('E03','E.지출','Q08 장비구입비 승인지출/잔액/집행률','2000000.00/3000000.00/40.00',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='장비구입비'"));
CALL t_expect_error('E04','E.지출','승인된 지출 재승인 거부(이중 집계 방지)',"CALL process_expenditure(@exp_equip,@u_admin2,'APPROVED','재시도')",1644,'%중복 승인%');
CALL t_expect_error('E05','E.지출','승인된 지출을 반려로 번복 거부',"CALL process_expenditure(@exp_equip,@u_admin2,'REJECTED','번복')",1644,'%PENDING%');
CALL t_check('E06','E.지출','재시도 후에도 승인지출 2,000,000 | 로그 1건','2000000.00|1',
 CONCAT("SELECT CONCAT((SELECT approved_spend FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='장비구입비'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='expenditure' AND target_id=@exp_equip))"));
CALL t_expect_ok('E07','E.지출','글로벌 인건비 대기 1,000,000원 반려',"CALL process_expenditure(@exp_glob,@u_admin2,'REJECTED','증빙 부족')");
CALL t_check('E08','E.지출','반려는 합산 제외: 글로벌 인건비 승인지출/잔액/집행률 불변','4000000.00/4000000.00/50.00',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='글로벌 인재양성 사업' AND category_name='인건비'"));
CALL t_expect_error('E09','E.지출','반려된 지출을 다시 승인 거부',"CALL process_expenditure(@exp_glob,@u_admin2,'APPROVED','재시도')",1644,'%PENDING%');
CALL t_expect_ok('E10','E.지출','학생인건비 대기 1,000,000원 반려',"CALL process_expenditure(@exp_stu,@u_admin2,'REJECTED','예산 계획 외')");
CALL t_check('E11','E.지출','학생인건비 승인지출/잔액/집행률 불변(3.0M+2.0M+0.5M)','5500000.00/4500000.00/55.00',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='학생인건비'"));
CALL t_expect_error('E12','E.지출','존재하지 않는 지출 처리 거부',"CALL process_expenditure(999999,@u_admin2,'APPROVED','x')",1644,'%PENDING%');

-- E-2 예산 한도: 운영비 예산 1,500,000 / 기존 승인 200,000
INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',1400000,'T-한도초과');
SET @exp_over = LAST_INSERT_ID();
CALL t_expect_error('E13','E.예산한도','비관리자(학생)의 지출 승인 시도 거부',"CALL process_expenditure(@exp_over,@u_stu1,'APPROVED','x')",1644,'%관리자%');
CALL t_expect_error('E14','E.예산한도','한도 초과 승인 차단: 200,000+1,400,000 > 1,500,000',"CALL process_expenditure(@exp_over,@u_admin2,'APPROVED','예산 초과 차단 확인')",1644,'%예산 한도 초과%');
CALL t_check('E15','E.예산한도','차단 후 상태|운영비 승인지출|로그수 = 변경 없음','PENDING|200000.00|0',
 CONCAT("SELECT CONCAT((SELECT status FROM expenditure WHERE expenditure_id=@exp_over),'|',(SELECT approved_spend FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='운영비'),'|',(SELECT COUNT(*) FROM change_log WHERE target_type='expenditure' AND target_id=@exp_over))"));
INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',1300000,'T-한도경계(승인)');
SET @exp_edge = LAST_INSERT_ID();
CALL t_expect_ok('E16','E.예산한도','경계: 200,000+1,300,000 = 1,500,000 (정확히 한도) 승인 허용',"CALL process_expenditure(@exp_edge,@u_admin2,'APPROVED','한도 경계 승인')");
CALL t_check('E17','E.예산한도','운영비 승인지출/잔액/집행률 = 1.5M / 0 / 100%','1500000.00/0.00/100.00',CONCAT("SELECT CONCAT(approved_spend,'/',balance,'/',execution_rate_pct) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND category_name='운영비'"));
INSERT INTO expenditure(professor_id,budget_id,spending_entity,amount,description) VALUES (@prof_kim,@bud_ops,'전공',0.01,'T-한도+0.01');
SET @exp_edge1 = LAST_INSERT_ID();
CALL t_expect_error('E18','E.예산한도','경계: 한도 소진 후 0.01원도 승인 차단',"CALL process_expenditure(@exp_edge1,@u_admin2,'APPROVED','x')",1644,'%예산 한도 초과%');

-- E-3 집계 정확성 (무지출 항목 포함, JOIN 중복 없음, 0 나누기 방지)
CALL t_check('E19','E.집계','Q08 SW사업 예산항목 7개 모두 표시(LEFT JOIN)','7',CONCAT("SELECT COUNT(*) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업'"));
CALL t_check('E20','E.집계','승인 지출 없는 항목(인건비·여비교통비·연구활동비·기타): 잔액=예산','4',CONCAT("SELECT COUNT(*) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업' AND approved_spend=0 AND balance=budget_amount"));
-- 수작업 근거: 장비 2.0M + 학생인건비 5.5M + 운영비 1.5M = 9.0M (JOIN으로 부풀려지면 안 됨)
CALL t_check('E21','E.집계','Q08 SW사업 승인지출 합계 = 9,000,000','9000000.00',CONCAT("SELECT SUM(approved_spend) FROM (",@q08,") q WHERE project_name='2026년 SW중심대학 사업'"));
CALL t_check('E22','E.집계','Q09 김교수/산학협력 = 1.5M+0.5M, 2건','2000000.00/2',CONCAT("SELECT CONCAT(approved_spend,'/',approved_count) FROM (",@q09,") q WHERE professor_name='김교수' AND spending_entity='산학협력'"));
CALL t_check('E23','E.집계','Q09 김교수/전공 = 3.0M+0.5M+1.3M, 3건','4800000.00/3',CONCAT("SELECT CONCAT(approved_spend,'/',approved_count) FROM (",@q09,") q WHERE professor_name='김교수' AND spending_entity='전공'"));
CALL t_check('E24','E.집계','Q09 박교수/융합 4.2M, 이교수/전공 2.0M(반려·대기 제외)','4200000.00|2000000.00',CONCAT("SELECT CONCAT((SELECT approved_spend FROM (",@q09,") q WHERE professor_name='박교수' AND spending_entity='융합'),'|',(SELECT approved_spend FROM (",@q09,") q WHERE professor_name='이교수' AND spending_entity='전공'))"));
CALL t_check('E25','E.집계','Q09 전체 합계 = 전체 승인 지출 13,000,000(11.2M+0.5M+1.3M)','13000000.00',CONCAT("SELECT SUM(approved_spend) FROM (",@q09,") q"));
INSERT INTO budget(project_id,category_id,amount)
SELECT p.project_id,c.category_id,0 FROM budget_project p JOIN category c ON c.category_name='기타' WHERE p.project_name='글로벌 인재양성 사업';
SET @bud_zero = LAST_INSERT_ID();
CALL t_check('E26','E.집계','예산 0원 항목에서도 Q08 오류 없이 집행률 0 (0 나누기 방지)','1',CONCAT("SELECT execution_rate_pct=0 FROM (",@q08,") q WHERE project_name='글로벌 인재양성 사업' AND category_name='기타'"));

-- =====================================================================
-- F. 만족도 (미션 §7-9): 1~5점 범위, 중복 응답, 완료 응답 기준
--   채택 정책: 설문당 학생 1회 응답(UNIQUE(survey_id,student_id)), 점수 1~5, 주관식은 빈 문자열 불가.
--   완료 응답 = 해당 설문의 모든 문항에 답변이 있는 응답 (Q10 기준)
-- =====================================================================
CALL t_expect_error('F01','F.만족도','같은 학생이 같은 설문에 중복 응답 거부',"INSERT INTO survey_response(survey_id,student_id) VALUES (@sv1,@sid1)",1062,'%Duplicate%');
-- 응답이 없던 20240006 학생의 응답 헤더(이후 정리 단계에서 삭제)
INSERT INTO survey_response(survey_id,student_id) VALUES (@sv1,@sid6);
SET @resp6 = LAST_INSERT_ID();
CALL t_expect_error('F02','F.만족도','점수 0 거부(하한 미만)',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q1,'SCORE',0)",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F03','F.만족도','점수 6 거부(상한 초과)',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q1,'SCORE',6)",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F04','F.만족도','점수와 주관식을 동시에 입력 거부',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score,answer_text) VALUES (@resp6,@sv1,@q3,'TEXT',3,'의견')",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F05','F.만족도','빈 문자열 주관식 거부',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,answer_text) VALUES (@resp6,@sv1,@q3,'TEXT','')",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F06','F.만족도','공백만 있는 주관식 거부',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,answer_text) VALUES (@resp6,@sv1,@q3,'TEXT','   ')",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F07','F.만족도','점수/주관식 모두 NULL 거부',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score,answer_text) VALUES (@resp6,@sv1,@q3,'TEXT',NULL,NULL)",3819,'%chk_survey_answer_type%');
CALL t_expect_error('F08','F.만족도','다른 설문의 문항에 답변 거부(복합 FK)',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv2,@q1,'SCORE',3)",1452,'%foreign key%');
CALL t_expect_ok('F09','F.만족도','점수 1 허용(하한 경계)',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q1,'SCORE',1)");
CALL t_expect_ok('F10','F.만족도','점수 5 허용(상한 경계)',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q2,'SCORE',5)");
CALL t_expect_error('F11','F.만족도','같은 응답의 같은 문항 중복 답변 거부',"INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q1,'SCORE',2)",1062,'%Duplicate%');
-- 지금 resp6은 3문항 중 2개만 답변한 "미완료" 응답. 단순 AVG에는 섞이지만 Q10에서는 제외되어야 한다.
-- 수작업 근거: 단순 평균 (21+1)/6 = 3.67 vs 완료 응답만 21/5 = 4.20
CALL t_check('F12','F.만족도','(참고) 미완료 응답을 포함한 단순 평균은 3.67','3.67',"SELECT ROUND(AVG(score),2) FROM survey_answer WHERE question_id=@q1");
CALL t_check('F13','F.만족도','Q10은 미완료 응답 제외: 평균/응답수 = 4.20/5','4.20/5',CONCAT("SELECT CONCAT(average_score,'/',numeric_response_count) FROM (",@q10,") q WHERE title='SW사업 만족도 조사' AND question_text='프로그램 전반에 만족하십니까?'"));
-- 문항 유형 불일치·타 설문 답변 연결은 복합 FK/CHECK가 막는다(스키마 강제). 거부되어야 PASS.
CALL t_expect_error('F14','F.만족도','TEXT 문항에 SCORE 유형·점수 답변 저장 거부(복합 FK: 문항 유형 일치)',
 "INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv1,@q3,'SCORE',3)",1452,'%fk_answer_question%');
CALL t_expect_error('F15','F.만족도','응답(설문1)에 다른 설문(설문2)의 답변 연결 거부(복합 FK: 응답-설문 일치)',
 "INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score) VALUES (@resp6,@sv2,@q_g1,'SCORE',3)",1452,'%fk_answer_response%');

-- =====================================================================
-- G. 다른 학생 데이터 접근 통제 (미션 §7-10)
--   구현한 것: fn_can_view_student() = role_policy 기반 판정 함수(01_schema.sql 정의) + Q01에서 사용
--   미구현   : DB 계정별 GRANT / VIEW·행 단위 보안으로 임의 SELECT 자체를 막는 것 (애플리케이션 계층 필요)
-- =====================================================================
CALL t_check('G01','G.접근통제','학생(본인) -> 본인 학번 조회 허용','1',"SELECT fn_can_view_student(@u_stu1,'20240001')");
CALL t_check('G02','G.접근통제','학생 -> 타 학생 학번 조회 차단','0',"SELECT fn_can_view_student(@u_stu1,'20240002')");
CALL t_check('G03','G.접근통제','일반관리자 -> 학생 조회 허용','1',"SELECT fn_can_view_student(@u_admin1,'20240002')");
CALL t_check('G04','G.접근통제','교수 계정 -> 학생 조회 차단(권한 없음)','0',"SELECT fn_can_view_student(@u_prof1,'20240001')");
SET @student_no='20240001'; SET @requester_user_id=@u_stu1;
CALL t_check('G05','G.접근통제','Q01(권한 포함): 학생 본인 조회 시 1행','1',CONCAT("SELECT COUNT(*) FROM (",@q01,") q"));
SET @student_no='20240002';
CALL t_check('G06','G.접근통제','Q01(권한 포함): 학생이 타 학생 조회 시 0행','0',CONCAT("SELECT COUNT(*) FROM (",@q01,") q"));
SET @requester_user_id=@u_admin1;
CALL t_check('G06a','G.접근통제','Q01(권한 포함): 일반관리자가 타 학생 조회 시 1행','1',CONCAT("SELECT COUNT(*) FROM (",@q01,") q"));
SET @requester_user_id=@u_prof1;
CALL t_check('G06b','G.접근통제','Q01(권한 포함): 교수 계정 조회 시 0행','0',CONCAT("SELECT COUNT(*) FROM (",@q01,") q"));
SET @student_no='20240001'; SET @requester_user_id=@u_admin1; -- 이후 테스트를 위해 복원
CALL t_check('G07','G.접근통제','role_policy: 학생 역할의 student_profile 조회 범위(정책 데이터)','본인 학생 정보만 조회',"SELECT rp.scope_description FROM role_policy rp JOIN role r ON r.role_id=rp.role_id WHERE r.role_name='학생' AND rp.resource_name='student_profile' AND rp.permission_name='READ'");
-- 승인 프로시저의 권한 판정이 role_policy 데이터를 참조하는지 (역할명이 하드코딩인지) 확인
SELECT COALESCE(MAX(ROUTINE_DEFINITION LIKE '%role_policy%'),0) INTO @proc_uses_policy FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='pbl_db' AND ROUTINE_NAME='process_expenditure';
CALL t_record('G08','G.접근통제','process_expenditure의 권한 판정이 role_policy 데이터를 참조',
 '참조함','참조하지 않음(역할명 하드코딩: 일반관리자/최고관리자)',IF(@proc_uses_policy=1,'PASS','GAP'));
SELECT COALESCE(MAX(ROUTINE_DEFINITION LIKE '%role_policy%'),0) INTO @fn_uses_policy FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='pbl_db' AND ROUTINE_NAME='fn_can_view_student';
CALL t_record('G08a','G.접근통제','fn_can_view_student의 권한 판정이 role_policy 데이터를 참조(테스트에서 재정의되지 않음)','참조함','참조하지 않음',IF(@fn_uses_policy=1,'PASS','FAIL'));
CALL t_record('G09','G.접근통제','DB 계정(GRANT)/행 단위 보안으로 임의 SELECT 차단','구현 시 시연','미구현: 애플리케이션 인증/인가로 별도 구현 필요','INFO');

-- =====================================================================
-- H. 로그 일관성 (업무 데이터와 change_log가 어긋나지 않는가)
-- =====================================================================
CALL t_check('H01','H.로그','처리 완료된 변경요청 중 "정확히 1건의 로그"가 아닌 것','0',
 "SELECT COUNT(*) FROM (SELECT r.request_id FROM student_change_request r LEFT JOIN change_log l ON l.target_type='student_change_request' AND l.target_id=r.request_id AND l.action_type=r.request_status WHERE r.request_status IN ('APPROVED','REJECTED') GROUP BY r.request_id HAVING COUNT(l.log_id)<>1) t");
SET @target_type='student_change_request';
CALL t_check('H02','H.로그','Q12 변경요청 로그 5건 = 시드 3 + 이번 승인/반려 2','5',CONCAT("SELECT COUNT(*) FROM (",@q12,") q"));
SET @target_type='mileage_application';
CALL t_check('H03','H.로그','Q12 마일리지 로그 3건 = 승인2 + 반려1 (실패·재시도는 로그 없음)','3',CONCAT("SELECT COUNT(*) FROM (",@q12,") q"));
SET @target_type='expenditure';
CALL t_check('H04','H.로그','Q12 지출 로그 4건 = 승인2 + 반려2 (차단·재시도는 로그 없음)','4',CONCAT("SELECT COUNT(*) FROM (",@q12,") q"));
SET @target_type=NULL;
CALL t_check('H05','H.로그','롤백된 시도(FORCE_FAIL)는 로그에 남지 않음','0',"SELECT COUNT(*) FROM change_log WHERE change_detail LIKE '%FORCE_FAIL%'");

-- =====================================================================
-- Z. 정리: 오류 테스트용 임시 데이터 삭제 (승인/반려 처리 결과는 증거로 남김)
-- =====================================================================
DELETE FROM topcit_score WHERE exam_id=@exam_t;
DELETE FROM topcit_exam WHERE exam_id=@exam_t;
DELETE FROM expenditure WHERE description LIKE 'T-%' AND status='PENDING';
DELETE FROM student_change_request WHERE request_id=@req_bad;
DELETE FROM survey_answer WHERE response_id=@resp6;
DELETE FROM survey_response WHERE response_id=@resp6;
DELETE FROM budget WHERE budget_id=@bud_zero;

-- 기대: 점수 20 / 회차 2 / 응답 10 / 답변 30 / 예산 8 / 변경요청 5 / 지출 11(시드 10 + 한도경계 승인 1) / 대기 지출 0
CALL t_check('Z01','Z.정리','임시 데이터 정리 후 건수(점수/회차/응답/답변/예산/변경요청/지출/대기지출)','20/2/10/30/8/5/11/0',
 "SELECT CONCAT((SELECT COUNT(*) FROM topcit_score),'/',(SELECT COUNT(*) FROM topcit_exam),'/',(SELECT COUNT(*) FROM survey_response),'/',(SELECT COUNT(*) FROM survey_answer),'/',(SELECT COUNT(*) FROM budget),'/',(SELECT COUNT(*) FROM student_change_request),'/',(SELECT COUNT(*) FROM expenditure),'/',(SELECT COUNT(*) FROM expenditure WHERE status='PENDING'))");

-- =====================================================================
-- 결과 출력
-- =====================================================================
SELECT seq,test_id,category,description,expected,actual,result FROM tmp_test_result ORDER BY seq;
SELECT result,COUNT(*) AS cnt FROM tmp_test_result GROUP BY result ORDER BY FIELD(result,'FAIL','GAP','INFO','PASS');

-- 도우미 프로시저 정리 (fn_can_view_student는 01_schema.sql 소속이므로 삭제하지 않음)
DROP PROCEDURE IF EXISTS t_record;
DROP PROCEDURE IF EXISTS t_expect_error;
DROP PROCEDURE IF EXISTS t_expect_ok;
DROP PROCEDURE IF EXISTS t_check;
DROP PROCEDURE IF EXISTS t_gap;
