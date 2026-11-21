-- 정상 가상 데이터. 반드시 01_schema.sql 실행 후 빈 DB에서 1회 실행.
USE pbl_db;

INSERT INTO role(role_name) VALUES ('학생'),('일반관리자'),('최고관리자'),('교수');

INSERT INTO user_account(login_id,user_name,email) VALUES
('student01','김민준','student01@example.com'),('student02','이서연','student02@example.com'),
('student03','박지호','student03@example.com'),('student04','최유진','student04@example.com'),
('student05','정도윤','student05@example.com'),('student06','강하은','student06@example.com'),
('student07','조현우','student07@example.com'),('student08','윤서준','student08@example.com'),
('student09','장예린','student09@example.com'),('student10','임시우','student10@example.com'),
('admin01','일반관리자','admin01@example.com'),('admin02','최고관리자','admin02@example.com'),
('prof01','김교수','prof01@example.com'),('prof02','이교수','prof02@example.com'),('prof03','박교수','prof03@example.com');

INSERT INTO user_role(user_id,role_id)
SELECT u.user_id,r.role_id FROM user_account u JOIN role r ON r.role_name='학생' WHERE u.login_id LIKE 'student%';
INSERT INTO user_role(user_id,role_id)
SELECT u.user_id,r.role_id FROM user_account u JOIN role r ON r.role_name='일반관리자' WHERE u.login_id='admin01';
INSERT INTO user_role(user_id,role_id)
SELECT u.user_id,r.role_id FROM user_account u JOIN role r ON r.role_name='최고관리자' WHERE u.login_id='admin02';
INSERT INTO user_role(user_id,role_id)
SELECT u.user_id,r.role_id FROM user_account u JOIN role r ON r.role_name='교수' WHERE u.login_id LIKE 'prof%';

-- 역할별 정책 10건. scope_type: OWN=본인 데이터만, ALL=전체. 승인 프로시저가 이 데이터로 권한을 판정한다.
-- 정책 근거: 일반관리자는 조회+학생정보/마일리지 승인, 예산·지출 승인은 마스터관리자(최고관리자)만.
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'student_profile','READ','OWN','본인 학생 정보만 조회' FROM role WHERE role_name='학생';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'mileage_application','CREATE','OWN','본인 마일리지 신청' FROM role WHERE role_name='학생';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'student_profile','READ','ALL','전체 학생 정보 조회(수정 불가)' FROM role WHERE role_name='일반관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'student_change_request','APPROVE','ALL','학생 정보 변경 요청 처리' FROM role WHERE role_name='일반관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'mileage_application','APPROVE','ALL','마일리지 신청 승인 및 반려' FROM role WHERE role_name='일반관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'student_profile','READ','ALL','전체 학생 정보 조회' FROM role WHERE role_name='최고관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'student_change_request','APPROVE','ALL','학생 정보 변경 요청 처리' FROM role WHERE role_name='최고관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'mileage_application','APPROVE','ALL','마일리지 신청 승인 및 반려' FROM role WHERE role_name='최고관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'expenditure','APPROVE','ALL','지출 승인 및 반려' FROM role WHERE role_name='최고관리자';
INSERT INTO role_policy(role_id,resource_name,permission_name,scope_type,scope_description)
SELECT role_id,'change_log','READ','ALL','전체 변경 이력 조회' FROM role WHERE role_name='최고관리자';

INSERT INTO student(user_id,student_no,college,department,major_type,campus,grade,academic_status,admission_type,admission_date,phone,sms_opt_in)
SELECT user_id,
CASE login_id
WHEN 'student01' THEN '20240001' WHEN 'student02' THEN '20240002' WHEN 'student03' THEN '20240003'
WHEN 'student04' THEN '20240004' WHEN 'student05' THEN '20240005' WHEN 'student06' THEN '20240006'
WHEN 'student07' THEN '20240007' WHEN 'student08' THEN '20240008' WHEN 'student09' THEN '20240009'
ELSE '20240010' END,
'공과대학',
CASE WHEN CAST(SUBSTRING(login_id,8) AS UNSIGNED)<=5 THEN '소프트웨어학과' ELSE '정보통신공학과' END,
CASE WHEN CAST(SUBSTRING(login_id,8) AS UNSIGNED)<=5 THEN '공학' ELSE '자연' END,
'천안캠퍼스', CASE WHEN CAST(SUBSTRING(login_id,8) AS UNSIGNED)<=5 THEN 1 ELSE 2 END,
CASE WHEN login_id IN ('student03','student08') THEN '휴학' ELSE '재학' END,
CASE WHEN login_id IN ('student09','student10') THEN '편입학' ELSE '신입학' END,
'2024-03-04',NULL,FALSE
FROM user_account WHERE login_id LIKE 'student%' ORDER BY login_id;

-- 5건: PENDING 2, APPROVED 2, REJECTED 1. 과거 승인 건의 현재 값도 일치시킴.
UPDATE student SET phone='010-0000-0002' WHERE student_no='20240002';
UPDATE user_account u JOIN student s ON s.user_id=u.user_id SET u.email='new05@example.com' WHERE s.student_no='20240005';
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value,request_status,processed_by,processed_at,process_comment)
SELECT s.student_id,'phone',NULL,'010-0000-0001','PENDING',NULL,NULL,NULL FROM student s WHERE s.student_no='20240001';
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value,request_status,processed_by,processed_at,process_comment)
SELECT s.student_id,'phone',NULL,'010-0000-0002','APPROVED',u.user_id,'2026-10-20 10:00:00','기존 승인 이력 샘플' FROM student s JOIN user_account u ON u.login_id='admin01' WHERE s.student_no='20240002';
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value,request_status,processed_by,processed_at,process_comment)
SELECT s.student_id,'email','student03@example.com','new03@example.com','REJECTED',u.user_id,'2026-10-20 11:00:00','요청 값 확인 필요' FROM student s JOIN user_account u ON u.login_id='admin01' WHERE s.student_no='20240003';
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value,request_status)
SELECT student_id,'phone',NULL,'010-0000-0004','PENDING' FROM student WHERE student_no='20240004';
INSERT INTO student_change_request(student_id,requested_field,old_value,new_value,request_status,processed_by,processed_at,process_comment)
SELECT s.student_id,'email','student05@example.com','new05@example.com','APPROVED',u.user_id,'2026-10-20 12:00:00','기존 승인 이력 샘플' FROM student s JOIN user_account u ON u.login_id='admin02' WHERE s.student_no='20240005';

INSERT INTO topcit_exam(exam_name,exam_date,exam_round) VALUES
('TOPCIT 정기평가','2025-05-17','2025-상반기'),('TOPCIT 정기평가','2025-10-18','2025-하반기');
INSERT INTO topcit_score(student_id,exam_id,score)
SELECT s.student_id,e.exam_id,
CASE s.student_no
WHEN '20240001' THEN 620 WHEN '20240002' THEN 750 WHEN '20240003' THEN 480 WHEN '20240004' THEN 810 WHEN '20240005' THEN 560
WHEN '20240006' THEN 690 WHEN '20240007' THEN 720 WHEN '20240008' THEN 430 WHEN '20240009' THEN 880 ELSE 650 END
FROM student s CROSS JOIN topcit_exam e WHERE e.exam_round='2025-상반기';
INSERT INTO topcit_score(student_id,exam_id,score)
SELECT s.student_id,e.exam_id,
CASE s.student_no
WHEN '20240001' THEN 700 WHEN '20240002' THEN 790 WHEN '20240003' THEN 530 WHEN '20240004' THEN 850 WHEN '20240005' THEN 610
WHEN '20240006' THEN 740 WHEN '20240007' THEN 760 WHEN '20240008' THEN 500 WHEN '20240009' THEN 910 ELSE 710 END
FROM student s CROSS JOIN topcit_exam e WHERE e.exam_round='2025-하반기';

INSERT INTO program(program_name,start_date,end_date,mileage_points,evidence_required) VALUES
('AI 기초 특강','2026-03-01','2026-03-31',10,TRUE),
('클라우드 실습 워크숍','2026-04-01','2026-04-30',20,TRUE),
('SW 프로젝트 발표회','2026-05-01','2026-05-31',15,FALSE);
-- 10건 이상 신청, 상태별 예시 포함. 신청은 학생+프로그램별 1회 정책.
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-03-05 10:00:00','student01_ai.pdf','/evidence/student01_ai.pdf','APPROVED',a.user_id,'2026-03-10 10:00:00','참여 확인'
FROM student s JOIN program p ON p.program_name='AI 기초 특강' JOIN user_account a ON a.login_id='admin01' WHERE s.student_no='20240001';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-03-06 10:00:00','student02_ai.pdf','/evidence/student02_ai.pdf','PENDING',NULL,NULL,NULL FROM student s JOIN program p ON p.program_name='AI 기초 특강' WHERE s.student_no='20240002';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-03-07 10:00:00','student03_ai.pdf','/evidence/student03_ai.pdf','REJECTED',(SELECT user_id FROM user_account WHERE login_id='admin01'),'2026-03-11 10:00:00','증빙 불충분' FROM student s JOIN program p ON p.program_name='AI 기초 특강' WHERE s.student_no='20240003';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-04-05 10:00:00','student04_cloud.pdf','/evidence/student04_cloud.pdf','APPROVED',a.user_id,'2026-04-10 10:00:00','참여 확인'
FROM student s JOIN program p ON p.program_name='클라우드 실습 워크숍' JOIN user_account a ON a.login_id='admin02' WHERE s.student_no='20240004';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-04-06 10:00:00','student05_cloud.pdf','/evidence/student05_cloud.pdf','PENDING',NULL,NULL,NULL FROM student s JOIN program p ON p.program_name='클라우드 실습 워크숍' WHERE s.student_no='20240005';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-04-07 10:00:00','student06_cloud.pdf','/evidence/student06_cloud.pdf','APPROVED',a.user_id,'2026-04-11 10:00:00','참여 확인'
FROM student s JOIN program p ON p.program_name='클라우드 실습 워크숍' JOIN user_account a ON a.login_id='admin01' WHERE s.student_no='20240006';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-05-05 10:00:00','student07_show.pdf','/evidence/student07_show.pdf','PENDING',NULL,NULL,NULL FROM student s JOIN program p ON p.program_name='SW 프로젝트 발표회' WHERE s.student_no='20240007';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-05-06 10:00:00','student08_show.pdf','/evidence/student08_show.pdf','REJECTED',(SELECT user_id FROM user_account WHERE login_id='admin02'),'2026-05-12 10:00:00','참여 확인 불가' FROM student s JOIN program p ON p.program_name='SW 프로젝트 발표회' WHERE s.student_no='20240008';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-05-07 10:00:00','student09_show.pdf','/evidence/student09_show.pdf','APPROVED',a.user_id,'2026-05-13 10:00:00','참여 확인'
FROM student s JOIN program p ON p.program_name='SW 프로젝트 발표회' JOIN user_account a ON a.login_id='admin01' WHERE s.student_no='20240009';
INSERT INTO mileage_application(student_id,program_id,applied_at,evidence_file_name,evidence_location,application_status,processed_by,processed_at,process_comment)
SELECT s.student_id,p.program_id,'2026-05-08 10:00:00','student10_show.pdf','/evidence/student10_show.pdf','PENDING',NULL,NULL,NULL FROM student s JOIN program p ON p.program_name='SW 프로젝트 발표회' WHERE s.student_no='20240010';

INSERT INTO category(category_name) VALUES ('인건비'),('장비구입비'),('여비교통비'),('연구활동비'),('학생인건비'),('운영비'),('기타');
INSERT INTO budget_project(project_name) VALUES ('2026년 SW중심대학 사업'),('글로벌 인재양성 사업');
-- 프로젝트 1은 7개 예산항목 전부 등록. 여비교통비/기타 등 승인 지출 없는 항목 포함.
INSERT INTO budget(project_id,category_id,amount)
SELECT p.project_id,c.category_id,
CASE c.category_name WHEN '인건비' THEN 8000000 WHEN '장비구입비' THEN 5000000 WHEN '여비교통비' THEN 1000000
WHEN '연구활동비' THEN 2000000 WHEN '학생인건비' THEN 10000000 WHEN '운영비' THEN 1500000 ELSE 500000 END
FROM budget_project p CROSS JOIN category c WHERE p.project_name='2026년 SW중심대학 사업';
INSERT INTO budget(project_id,category_id,amount)
SELECT p.project_id,c.category_id,8000000 FROM budget_project p JOIN category c ON c.category_name='인건비'
WHERE p.project_name='글로벌 인재양성 사업';

INSERT INTO professor(professor_name,user_id)
SELECT '김교수',user_id FROM user_account WHERE login_id='prof01';
INSERT INTO professor(professor_name,user_id)
SELECT '이교수',user_id FROM user_account WHERE login_id='prof02';
INSERT INTO professor(professor_name,user_id)
SELECT '박교수',user_id FROM user_account WHERE login_id='prof03';

-- 지출 10건. 금액은 양수, 상태별 사례 포함.
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'산학협력',1500000,'APPROVED','GENERAL','장비 구매'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='장비구입비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='김교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'산학협력',500000,'PENDING','GENERAL','장비 구매 대기'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='장비구입비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='김교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,s.student_id,'전공',3000000,'APPROVED','STUDENT_LABOR','학생 연구 인건비'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='학생인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id
JOIN student s ON s.student_no='20240001' WHERE pr.professor_name='김교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,s.student_id,'전공',2000000,'APPROVED','STUDENT_LABOR','학생 연구 인건비'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='학생인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id
JOIN student s ON s.student_no='20240002' WHERE pr.professor_name='이교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,s.student_id,'융합',1000000,'PENDING','STUDENT_LABOR','승인 대기 학생 인건비'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='학생인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id
JOIN student s ON s.student_no='20240003' WHERE pr.professor_name='이교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'융합',4000000,'APPROVED','GENERAL','인건비'
FROM professor pr JOIN budget_project p ON p.project_name='글로벌 인재양성 사업'
JOIN category c ON c.category_name='인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='박교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'융합',1000000,'PENDING','GENERAL','인건비 대기'
FROM professor pr JOIN budget_project p ON p.project_name='글로벌 인재양성 사업'
JOIN category c ON c.category_name='인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='박교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,s.student_id,'전공',500000,'APPROVED','STUDENT_LABOR','학생 연구 인건비'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='학생인건비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id
JOIN student s ON s.student_no='20240004' WHERE pr.professor_name='김교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'산학협력',300000,'REJECTED','GENERAL','반려된 장비 구매'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='장비구입비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='이교수';
INSERT INTO expenditure(professor_id,budget_id,student_id,spending_entity,amount,status,expense_type,description)
SELECT pr.professor_id,b.budget_id,NULL,'융합',200000,'APPROVED','GENERAL','운영비'
FROM professor pr JOIN budget_project p ON p.project_name='2026년 SW중심대학 사업'
JOIN category c ON c.category_name='운영비' JOIN budget b ON b.project_id=p.project_id AND b.category_id=c.category_id WHERE pr.professor_name='박교수';

-- 2개 설문, 각 설문 3문항 이상(점수형 2 + 서술형 1).
INSERT INTO survey(project_id,title,start_date,end_date)
SELECT project_id,'SW사업 만족도 조사','2026-05-01','2026-06-30' FROM budget_project WHERE project_name='2026년 SW중심대학 사업';
INSERT INTO survey(project_id,title,start_date,end_date)
SELECT project_id,'글로벌 인재양성 만족도 조사','2026-05-01','2026-06-30' FROM budget_project WHERE project_name='글로벌 인재양성 사업';

INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'프로그램 전반에 만족하십니까?','SCORE',1 FROM survey WHERE title='SW사업 만족도 조사';
INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'운영 안내에 만족하십니까?','SCORE',2 FROM survey WHERE title='SW사업 만족도 조사';
INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'개선 의견을 작성해 주세요.','TEXT',3 FROM survey WHERE title='SW사업 만족도 조사';
INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'프로그램 전반에 만족하십니까?','SCORE',1 FROM survey WHERE title='글로벌 인재양성 만족도 조사';
INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'학습 내용에 만족하십니까?','SCORE',2 FROM survey WHERE title='글로벌 인재양성 만족도 조사';
INSERT INTO survey_question(survey_id,question_text,question_type,display_order)
SELECT survey_id,'개선 의견을 작성해 주세요.','TEXT',3 FROM survey WHERE title='글로벌 인재양성 만족도 조사';

-- 응답 헤더 10건, 설문별 5명. 전체 문항 답변 상세도 입력.
INSERT INTO survey_response(survey_id,student_id,submitted_at)
SELECT sv.survey_id,s.student_id,DATE_ADD('2026-06-01',INTERVAL CAST(SUBSTRING(s.student_no,5) AS UNSIGNED) DAY)
FROM survey sv CROSS JOIN student s
WHERE sv.title='SW사업 만족도 조사' AND CAST(SUBSTRING(s.student_no,5) AS UNSIGNED)<=5;
INSERT INTO survey_response(survey_id,student_id,submitted_at)
SELECT sv.survey_id,s.student_id,DATE_ADD('2026-06-10',INTERVAL CAST(SUBSTRING(s.student_no,5) AS UNSIGNED) DAY)
FROM survey sv CROSS JOIN student s
WHERE sv.title='글로벌 인재양성 만족도 조사' AND CAST(SUBSTRING(s.student_no,5) AS UNSIGNED)<=5;

INSERT INTO survey_answer(response_id,survey_id,question_id,question_type,score,answer_text)
SELECT r.response_id,r.survey_id,q.question_id,q.question_type,
CASE WHEN q.question_type='SCORE' THEN 3 + MOD(r.student_id,3) ELSE NULL END,
CASE WHEN q.question_type='TEXT' THEN CONCAT('개선 의견 예시 ',r.student_id) ELSE NULL END
FROM survey_response r JOIN survey_question q ON q.survey_id=r.survey_id;

-- 로그 예시: 기존 승인/반려 상태의 과거 이력. 신규 처리는 프로시저가 기록.
INSERT INTO change_log(actor_user_id,target_type,target_id,action_type,change_detail)
SELECT u.user_id,'student_change_request',r.request_id,r.request_status,
CONCAT('시드 이력: ',r.requested_field,' -> ',r.request_status)
FROM student_change_request r JOIN user_account u ON u.user_id=r.processed_by
WHERE r.request_status IN ('APPROVED','REJECTED');
INSERT INTO change_log(actor_user_id,target_type,target_id,action_type,change_detail)
SELECT e.processed_by,'expenditure',e.expenditure_id,e.status,CONCAT('시드 지출 상태: ',e.status)
FROM expenditure e WHERE e.status IN ('APPROVED','REJECTED') AND e.processed_by IS NOT NULL;

-- 데이터 규모 확인
SELECT (SELECT COUNT(*) FROM student) AS students,
       (SELECT COUNT(*) FROM student_change_request) AS change_requests,
       (SELECT COUNT(*) FROM topcit_score) AS topcit_scores,
       (SELECT COUNT(*) FROM program) AS programs,
       (SELECT COUNT(*) FROM mileage_application) AS mileage_applications,
       (SELECT COUNT(*) FROM category) AS budget_categories,
       (SELECT COUNT(*) FROM expenditure) AS expenditures,
       (SELECT COUNT(*) FROM survey) AS surveys,
       (SELECT COUNT(*) FROM survey_question) AS survey_questions,
       (SELECT COUNT(*) FROM survey_response) AS survey_responses,
       (SELECT COUNT(*) FROM survey_answer) AS survey_answers;
