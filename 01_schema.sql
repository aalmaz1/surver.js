-- PBL Mission 2 통합 스키마 (A+B+C)
-- DBMS: MySQL 8.0.16+ 권장 (CHECK 제약조건 적용)
-- 새 테스트 DB에서 실행할 것. 재설정은 README 참조.
CREATE DATABASE IF NOT EXISTS pbl_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pbl_db;

CREATE TABLE IF NOT EXISTS user_account (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  login_id VARCHAR(50) NOT NULL UNIQUE,
  user_name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS role (
  role_id INT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_role (
  user_id INT NOT NULL,
  role_id INT NOT NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_role_user FOREIGN KEY (user_id) REFERENCES user_account(user_id),
  CONSTRAINT fk_user_role_role FOREIGN KEY (role_id) REFERENCES role(role_id)
) ENGINE=InnoDB;

-- 역할별 정책 데이터. 승인 프로시저(process_*)와 fn_can_view_student가 이 데이터를 조회해 권한을 판정한다.
-- 실제 DB 계정(GRANT)/행 단위 보안 차단은 구현하지 않음(미구현 범위).
CREATE TABLE IF NOT EXISTS role_policy (
  policy_id INT AUTO_INCREMENT PRIMARY KEY,
  role_id INT NOT NULL,
  resource_name VARCHAR(80) NOT NULL,
  permission_name ENUM('READ','CREATE','UPDATE','APPROVE','ADMIN') NOT NULL,
  scope_type ENUM('OWN','ALL') NOT NULL DEFAULT 'ALL',  -- OWN: 본인 데이터만, ALL: 전체
  scope_description VARCHAR(255) NOT NULL,
  UNIQUE (role_id, resource_name, permission_name),
  FOREIGN KEY (role_id) REFERENCES role(role_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS student (
  student_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  student_no VARCHAR(20) NOT NULL UNIQUE,
  college VARCHAR(100) NOT NULL,
  department VARCHAR(100) NOT NULL,
  major_type ENUM('공학','자연') NOT NULL,
  campus VARCHAR(50) NOT NULL,
  grade TINYINT NOT NULL,
  academic_status ENUM('재학','휴학','졸업') NOT NULL DEFAULT '재학',
  admission_type ENUM('신입학','편입학') NOT NULL,
  admission_date DATE NULL,
  phone VARCHAR(20) NULL,
  sms_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT chk_student_grade CHECK (grade BETWEEN 1 AND 6),
  FOREIGN KEY (user_id) REFERENCES user_account(user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS student_change_request (
  request_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  requested_field ENUM('college','department','major_type','campus','grade','academic_status','admission_type','admission_date','phone','email') NOT NULL,
  old_value VARCHAR(500) NULL,
  new_value VARCHAR(500) NOT NULL,
  request_status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processed_by INT NULL,
  processed_at DATETIME NULL,
  process_comment VARCHAR(500) NULL,
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (processed_by) REFERENCES user_account(user_id),
  INDEX idx_change_request_status_time (request_status, requested_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS topcit_exam (
  exam_id INT AUTO_INCREMENT PRIMARY KEY,
  exam_name VARCHAR(100) NOT NULL,
  exam_date DATE NOT NULL,
  exam_round VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS topcit_score (
  score_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  exam_id INT NOT NULL,
  score INT NOT NULL,
  UNIQUE (student_id, exam_id),
  CONSTRAINT chk_topcit_score_range CHECK (score BETWEEN 0 AND 1000),
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (exam_id) REFERENCES topcit_exam(exam_id)
) ENGINE=InnoDB;

-- 프로그램 및 마일리지
CREATE TABLE IF NOT EXISTS program (
  program_id INT AUTO_INCREMENT PRIMARY KEY,
  program_name VARCHAR(150) NOT NULL UNIQUE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  mileage_points INT NOT NULL,
  evidence_required BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT chk_program_dates CHECK (end_date >= start_date),
  CONSTRAINT chk_program_mileage CHECK (mileage_points > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mileage_application (
  application_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  program_id INT NOT NULL,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  evidence_file_name VARCHAR(255) NULL,
  evidence_location VARCHAR(500) NULL,
  application_status ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  processed_by INT NULL,
  processed_at DATETIME NULL,
  process_comment VARCHAR(500) NULL,
  UNIQUE (student_id, program_id),
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (program_id) REFERENCES program(program_id),
  FOREIGN KEY (processed_by) REFERENCES user_account(user_id),
  INDEX idx_mileage_status_time (application_status, applied_at)
) ENGINE=InnoDB;

-- 예산 및 지출
CREATE TABLE IF NOT EXISTS category (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget_project (
  project_id INT AUTO_INCREMENT PRIMARY KEY,
  project_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget (
  budget_id INT AUTO_INCREMENT PRIMARY KEY,
  project_id INT NOT NULL,
  category_id INT NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  UNIQUE (project_id, category_id),
  CONSTRAINT chk_budget_amount CHECK (amount >= 0),
  FOREIGN KEY (project_id) REFERENCES budget_project(project_id),
  FOREIGN KEY (category_id) REFERENCES category(category_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS professor (
  professor_id INT AUTO_INCREMENT PRIMARY KEY,
  professor_name VARCHAR(50) NOT NULL,
  user_id INT NULL UNIQUE,
  FOREIGN KEY (user_id) REFERENCES user_account(user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS expenditure (
  expenditure_id INT AUTO_INCREMENT PRIMARY KEY,
  professor_id INT NOT NULL,
  budget_id INT NOT NULL,
  student_id INT NULL,
  spending_entity ENUM('산학협력','전공','융합') NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  expense_type ENUM('GENERAL','STUDENT_LABOR') NOT NULL DEFAULT 'GENERAL',
  description VARCHAR(255) NULL,
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processed_by INT NULL,
  processed_at DATETIME NULL,
  process_comment VARCHAR(500) NULL,
  CONSTRAINT chk_expenditure_positive CHECK (amount > 0),
  CONSTRAINT chk_student_labor CHECK (
    (expense_type = 'STUDENT_LABOR' AND student_id IS NOT NULL) OR
    (expense_type = 'GENERAL' AND student_id IS NULL)
  ),
  FOREIGN KEY (professor_id) REFERENCES professor(professor_id),
  FOREIGN KEY (budget_id) REFERENCES budget(budget_id),
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (processed_by) REFERENCES user_account(user_id),
  INDEX idx_expenditure_status (status, budget_id)
) ENGINE=InnoDB;

-- 만족도. 점수형/서술형을 명시하고 답변 유형에 맞는 값만 저장한다.
CREATE TABLE IF NOT EXISTS survey (
  survey_id INT AUTO_INCREMENT PRIMARY KEY,
  project_id INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  UNIQUE (project_id, title),
  CONSTRAINT chk_survey_dates CHECK (end_date >= start_date),
  FOREIGN KEY (project_id) REFERENCES budget_project(project_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS survey_question (
  question_id INT AUTO_INCREMENT PRIMARY KEY,
  survey_id INT NOT NULL,
  question_text VARCHAR(255) NOT NULL,
  question_type ENUM('SCORE','TEXT') NOT NULL,
  display_order INT NOT NULL,
  UNIQUE (survey_id, display_order),
  UNIQUE (survey_id, question_id),
  UNIQUE (survey_id, question_id, question_type),  -- survey_answer의 복합 FK가 참조 (문항 유형 일치 강제)
  FOREIGN KEY (survey_id) REFERENCES survey(survey_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS survey_response (
  response_id INT AUTO_INCREMENT PRIMARY KEY,
  survey_id INT NOT NULL,
  student_id INT NOT NULL,
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (survey_id, student_id),
  UNIQUE (response_id, survey_id),  -- survey_answer의 복합 FK가 참조 (응답-설문 일치 강제)
  FOREIGN KEY (survey_id) REFERENCES survey(survey_id),
  FOREIGN KEY (student_id) REFERENCES student(student_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS survey_answer (
  answer_id INT AUTO_INCREMENT PRIMARY KEY,
  response_id INT NOT NULL,
  survey_id INT NOT NULL,
  question_id INT NOT NULL,
  question_type ENUM('SCORE','TEXT') NOT NULL,  -- 문항 유형을 복제 저장하고 FK로 survey_question과 일치 강제
  score TINYINT NULL,
  answer_text TEXT NULL,
  UNIQUE (response_id, question_id),
  -- 문항 유형에 맞는 값만 허용: SCORE 문항=1~5점만, TEXT 문항=비어 있지 않은 글만
  CONSTRAINT chk_survey_answer_type CHECK (
    (question_type = 'SCORE' AND score IS NOT NULL AND score BETWEEN 1 AND 5 AND answer_text IS NULL) OR
    (question_type = 'TEXT' AND score IS NULL AND answer_text IS NOT NULL AND CHAR_LENGTH(TRIM(answer_text)) > 0)
  ),
  -- 응답이 속한 설문과 답변의 설문이 같아야 함
  CONSTRAINT fk_answer_response FOREIGN KEY (response_id, survey_id) REFERENCES survey_response(response_id, survey_id),
  -- 문항이 그 설문의 문항이고, 선언한 유형이 실제 문항 유형과 같아야 함
  CONSTRAINT fk_answer_question FOREIGN KEY (survey_id, question_id, question_type) REFERENCES survey_question(survey_id, question_id, question_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_log (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  actor_user_id INT NULL,
  target_type VARCHAR(50) NOT NULL,
  target_id INT NOT NULL,
  action_type VARCHAR(30) NOT NULL,
  change_detail TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (actor_user_id) REFERENCES user_account(user_id),
  INDEX idx_log_target (target_type, target_id, created_at)
) ENGINE=InnoDB;

-- =====================================================
-- 업무 처리 프로시저 (요구 제출 파일 구성에 따라 01_schema.sql에 포함)
-- =====================================================
DELIMITER $$

-- 사용자가 특정 자원에 대해 특정 권한을 가졌는지 role_policy 데이터로 판정 (활성 계정만)
DROP FUNCTION IF EXISTS fn_has_permission$$
CREATE FUNCTION fn_has_permission(p_user_id INT, p_resource VARCHAR(80), p_permission VARCHAR(20))
RETURNS TINYINT(1) READS SQL DATA
RETURN EXISTS (
  SELECT 1 FROM user_account u
  JOIN user_role ur ON ur.user_id=u.user_id
  JOIN role_policy rp ON rp.role_id=ur.role_id
  WHERE u.user_id=p_user_id AND u.is_active=TRUE
    AND rp.resource_name=p_resource AND rp.permission_name=p_permission
)$$

-- 학생 기본정보 조회 허용 여부: 전체(ALL) 조회 정책이 있거나, 본인(OWN) 조회 정책이 있고 본인 학번일 때
DROP FUNCTION IF EXISTS fn_can_view_student$$
CREATE FUNCTION fn_can_view_student(p_requester_user_id INT, p_student_no VARCHAR(20))
RETURNS TINYINT(1) READS SQL DATA
RETURN (
  EXISTS (SELECT 1 FROM user_account u JOIN user_role ur ON ur.user_id=u.user_id
          JOIN role_policy rp ON rp.role_id=ur.role_id
          WHERE u.user_id=p_requester_user_id AND u.is_active=TRUE
            AND rp.resource_name='student_profile' AND rp.permission_name='READ' AND rp.scope_type='ALL')
  OR EXISTS (SELECT 1 FROM user_account u JOIN user_role ur ON ur.user_id=u.user_id
          JOIN role_policy rp ON rp.role_id=ur.role_id
          JOIN student s ON s.user_id=u.user_id
          WHERE u.user_id=p_requester_user_id AND u.is_active=TRUE AND s.student_no=p_student_no
            AND rp.resource_name='student_profile' AND rp.permission_name='READ' AND rp.scope_type='OWN')
)$$

DROP PROCEDURE IF EXISTS process_student_change_request$$
CREATE PROCEDURE process_student_change_request(
  IN p_request_id INT, IN p_processed_by INT, IN p_decision VARCHAR(20), IN p_comment VARCHAR(500)
)
proc: BEGIN
  DECLARE v_student_id INT DEFAULT NULL;
  DECLARE v_user_id INT DEFAULT NULL;
  DECLARE v_field VARCHAR(50);
  DECLARE v_new_value VARCHAR(500);
  DECLARE v_status VARCHAR(20);
  DECLARE v_decision VARCHAR(20);
  DECLARE v_found BOOLEAN DEFAULT TRUE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET v_decision=UPPER(TRIM(p_decision));
  IF v_decision NOT IN ('APPROVED','REJECTED') OR v_decision IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='decision은 APPROVED 또는 REJECTED여야 합니다.';
  END IF;
  START TRANSACTION;
  IF NOT fn_has_permission(p_processed_by,'student_change_request','APPROVE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='관리자 승인 권한이 없습니다(role_policy).';
  END IF;
  SELECT student_id,requested_field,new_value,request_status
    INTO v_student_id,v_field,v_new_value,v_status
    FROM student_change_request WHERE request_id=p_request_id FOR UPDATE;
  IF v_status IS NULL OR v_status<>'PENDING' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PENDING 요청만 처리할 수 있습니다.';
  END IF;
  IF v_decision='APPROVED' THEN
    SELECT user_id INTO v_user_id FROM student WHERE student_id=v_student_id;
    CASE v_field
      WHEN 'college' THEN UPDATE student SET college=v_new_value WHERE student_id=v_student_id;
      WHEN 'department' THEN UPDATE student SET department=v_new_value WHERE student_id=v_student_id;
      WHEN 'major_type' THEN
        IF v_new_value NOT IN ('공학','자연') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='major_type 값 오류'; END IF;
        UPDATE student SET major_type=v_new_value WHERE student_id=v_student_id;
      WHEN 'campus' THEN UPDATE student SET campus=v_new_value WHERE student_id=v_student_id;
      WHEN 'grade' THEN
        IF v_new_value NOT REGEXP '^[1-6]$' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='grade는 1~6'; END IF;
        UPDATE student SET grade=CAST(v_new_value AS UNSIGNED) WHERE student_id=v_student_id;
      WHEN 'academic_status' THEN
        IF v_new_value NOT IN ('재학','휴학','졸업') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='academic_status 값 오류'; END IF;
        UPDATE student SET academic_status=v_new_value WHERE student_id=v_student_id;
      WHEN 'admission_type' THEN
        IF v_new_value NOT IN ('신입학','편입학') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='admission_type 값 오류'; END IF;
        UPDATE student SET admission_type=v_new_value WHERE student_id=v_student_id;
      WHEN 'admission_date' THEN
        IF STR_TO_DATE(v_new_value,'%Y-%m-%d') IS NULL OR v_new_value NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='admission_date는 YYYY-MM-DD'; END IF;
        UPDATE student SET admission_date=STR_TO_DATE(v_new_value,'%Y-%m-%d') WHERE student_id=v_student_id;
      WHEN 'phone' THEN UPDATE student SET phone=v_new_value WHERE student_id=v_student_id;
      WHEN 'email' THEN UPDATE user_account SET email=v_new_value WHERE user_id=v_user_id;
      ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='허용되지 않은 변경 항목';
    END CASE;
  END IF;
  UPDATE student_change_request SET request_status=v_decision,processed_by=p_processed_by,
    processed_at=CURRENT_TIMESTAMP,process_comment=p_comment WHERE request_id=p_request_id;
  INSERT INTO change_log(actor_user_id,target_type,target_id,action_type,change_detail)
  VALUES(p_processed_by,'student_change_request',p_request_id,v_decision,
    CONCAT('field=',v_field,'; new=',v_new_value,'; comment=',COALESCE(p_comment,'')));
  COMMIT;
END$$

DROP PROCEDURE IF EXISTS process_mileage_application$$
CREATE PROCEDURE process_mileage_application(
  IN p_application_id INT, IN p_processed_by INT, IN p_decision VARCHAR(20), IN p_comment VARCHAR(500)
)
proc: BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_decision VARCHAR(20);
  DECLARE v_program VARCHAR(150);
  DECLARE v_student INT;
  DECLARE v_points INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET v_decision=UPPER(TRIM(p_decision));
  IF v_decision NOT IN ('APPROVED','REJECTED') OR v_decision IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='decision은 APPROVED 또는 REJECTED여야 합니다.';
  END IF;
  START TRANSACTION;
  IF NOT fn_has_permission(p_processed_by,'mileage_application','APPROVE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='관리자 승인 권한이 없습니다(role_policy).';
  END IF;
  SELECT ma.application_status, p.program_name, ma.student_id, p.mileage_points
    INTO v_status,v_program,v_student,v_points
    FROM mileage_application ma JOIN program p ON p.program_id=ma.program_id
    WHERE ma.application_id=p_application_id FOR UPDATE;
  IF v_status IS NULL OR v_status<>'PENDING' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PENDING 신청만 처리할 수 있습니다. 중복 승인 방지.';
  END IF;
  UPDATE mileage_application SET application_status=v_decision,processed_by=p_processed_by,
    processed_at=CURRENT_TIMESTAMP,process_comment=p_comment WHERE application_id=p_application_id;
  INSERT INTO change_log(actor_user_id,target_type,target_id,action_type,change_detail)
  VALUES(p_processed_by,'mileage_application',p_application_id,v_decision,
    CONCAT('student_id=',v_student,'; program=',v_program,'; points=',v_points,'; comment=',COALESCE(p_comment,'')));
  COMMIT;
END$$

DROP PROCEDURE IF EXISTS process_expenditure$$
CREATE PROCEDURE process_expenditure(
  IN p_expenditure_id INT, IN p_processed_by INT, IN p_decision VARCHAR(20), IN p_comment VARCHAR(500)
)
proc: BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_decision VARCHAR(20);
  DECLARE v_budget_id INT;
  DECLARE v_budget_amount DECIMAL(15,2);
  DECLARE v_expense_amount DECIMAL(15,2);
  DECLARE v_spent DECIMAL(15,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET v_decision=UPPER(TRIM(p_decision));
  IF v_decision NOT IN ('APPROVED','REJECTED') OR v_decision IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='decision은 APPROVED 또는 REJECTED여야 합니다.';
  END IF;
  START TRANSACTION;
  IF NOT fn_has_permission(p_processed_by,'expenditure','APPROVE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='관리자 승인 권한이 없습니다(role_policy).';
  END IF;
  SELECT status,budget_id,amount INTO v_status,v_budget_id,v_expense_amount
    FROM expenditure WHERE expenditure_id=p_expenditure_id FOR UPDATE;
  IF v_status IS NULL OR v_status<>'PENDING' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PENDING 지출만 처리할 수 있습니다. 중복 승인 방지.';
  END IF;
  IF v_decision='APPROVED' THEN
    SELECT amount INTO v_budget_amount FROM budget WHERE budget_id=v_budget_id FOR UPDATE;
    SELECT COALESCE(SUM(amount),0) INTO v_spent FROM expenditure
      WHERE budget_id=v_budget_id AND status='APPROVED';
    IF v_spent + v_expense_amount > v_budget_amount THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='예산 한도 초과: 지출 승인 거부';
    END IF;
  END IF;
  UPDATE expenditure SET status=v_decision,processed_by=p_processed_by,
    processed_at=CURRENT_TIMESTAMP,process_comment=p_comment WHERE expenditure_id=p_expenditure_id;
  INSERT INTO change_log(actor_user_id,target_type,target_id,action_type,change_detail)
  VALUES(p_processed_by,'expenditure',p_expenditure_id,v_decision,
    CONCAT('budget_id=',v_budget_id,'; amount=',v_expense_amount,'; comment=',COALESCE(p_comment,'')));
  COMMIT;
END$$

DELIMITER ;

-- 실행 예시 (ID는 DB에서 확인 후 사용)
-- CALL process_student_change_request(1, 11, 'APPROVED', '확인 후 승인');
-- CALL process_mileage_application(2, 11, 'APPROVED', '참여 확인');
-- CALL process_expenditure(2, 11, 'REJECTED', '증빙 부족');

SHOW TABLES;
