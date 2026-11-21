"use strict";

const mysql = require("mysql2/promise");
const { execSync } = require("child_process");
const path = require("path");

function createMysqlStore(pool) {
  return {
    async session(loginId) {
      const [users] = await pool.query(
        "SELECT user_id, login_id, user_name, email, is_active FROM user_account WHERE login_id = ?",
        [loginId]
      );
      if (!users.length || !users[0].is_active) {
        const err = new Error("로그인할 수 없는 계정입니다.");
        err.status = 401;
        throw err;
      }
      const u = users[0];

      const [roles] = await pool.query(
        `SELECT r.role_name FROM user_role ur
         JOIN role r ON r.role_id = ur.role_id
         WHERE ur.user_id = ?`,
        [u.user_id]
      );
      const roleNames = roles.map((r) => r.role_name);

      const [students] = await pool.query(
        "SELECT student_id, student_no FROM student WHERE user_id = ?",
        [u.user_id]
      );
      const student = students[0] || null;

      const [profs] = await pool.query(
        "SELECT professor_id FROM professor WHERE user_id = ?",
        [u.user_id]
      );
      const professor = profs[0] || null;

      const [policies] = await pool.query(
        `SELECT rp.resource_name, rp.permission_name, rp.scope_type
         FROM user_role ur
         JOIN role_policy rp ON rp.role_id = ur.role_id
         WHERE ur.user_id = ?`,
        [u.user_id]
      );

      const hasPerm = (res, perm) =>
        policies.some((p) => p.resource_name === res && p.permission_name === perm);

      return {
        user_id: u.user_id,
        login_id: u.login_id,
        user_name: u.user_name,
        email: u.email,
        roles: roleNames,
        student_id: student ? student.student_id : null,
        student_no: student ? student.student_no : null,
        professor_id: professor ? professor.professor_id : null,
        permissions: {
          view_all_students:
            hasPerm("student_profile", "READ") &&
            policies.some((p) => p.resource_name === "student_profile" && p.scope_type === "ALL"),
          approve_change: hasPerm("student_change_request", "APPROVE"),
          approve_mileage: hasPerm("mileage_application", "APPROVE"),
          create_mileage: hasPerm("mileage_application", "CREATE"),
          approve_expenditure: hasPerm("expenditure", "APPROVE"),
          read_log: hasPerm("change_log", "READ"),
        },
      };
    },

    async reset() {
      // 01_schema.sql 및 02_seed.sql을 실행하여 DB 초기 상태로 완전 리셋
      const rootDir = path.resolve(__dirname);
      try {
        execSync(
          `powershell -Command "docker exec -i pbl-mysql mysql -uroot -ppblpass -e 'DROP DATABASE IF EXISTS pbl_db; CREATE DATABASE pbl_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; SET GLOBAL log_bin_trust_function_creators = 1;'"`,
          { stdio: "ignore" }
        );
        execSync(
          `powershell -Command "Get-Content (Join-Path '${rootDir}' '01_schema.sql') -Raw -Encoding utf8 | docker exec -i pbl-mysql mysql -uroot -ppblpass --default-character-set=utf8mb4"`,
          { stdio: "ignore" }
        );
        execSync(
          `powershell -Command "Get-Content (Join-Path '${rootDir}' '02_seed.sql') -Raw -Encoding utf8 | docker exec -i pbl-mysql mysql -uroot -ppblpass --default-character-set=utf8mb4"`,
          { stdio: "ignore" }
        );
      } catch (e) {
        console.error("DB reset error:", e.message);
      }
    },

    async meta() {
      const [programs] = await pool.query("SELECT * FROM program ORDER BY program_id");
      const [projects] = await pool.query("SELECT * FROM budget_project ORDER BY project_id");
      const [categories] = await pool.query("SELECT * FROM category ORDER BY category_id");
      const [budgets] = await pool.query(`
        SELECT b.*, bp.project_name, c.category_name
        FROM budget b
        JOIN budget_project bp ON bp.project_id = b.project_id
        JOIN category c ON c.category_id = b.category_id
        ORDER BY b.budget_id
      `);
      const [professors] = await pool.query("SELECT * FROM professor ORDER BY professor_id");
      const [students] = await pool.query(`
        SELECT s.student_id, s.student_no, u.user_name
        FROM student s
        JOIN user_account u ON u.user_id = s.user_id
        ORDER BY s.student_no
      `);
      const [surveys] = await pool.query(`
        SELECT sv.*, bp.project_name
        FROM survey sv
        JOIN budget_project bp ON bp.project_id = sv.project_id
        ORDER BY sv.survey_id
      `);
      for (const sv of surveys) {
        const [questions] = await pool.query(
          "SELECT * FROM survey_question WHERE survey_id = ? ORDER BY display_order",
          [sv.survey_id]
        );
        sv.questions = questions;
      }
      return {
        programs,
        projects,
        categories,
        budgets,
        professors,
        students,
        surveys,
        is_real_db: true,
      };
    },

    async q01(requesterUserId, studentNo) {
      const [rows] = await pool.query(
        `SELECT s.student_no, u.user_name, u.email, s.college, s.department, s.major_type,
                s.campus, s.grade, s.academic_status, s.admission_type, s.admission_date, s.phone
         FROM student s
         JOIN user_account u ON u.user_id = s.user_id
         WHERE s.student_no = ?
           AND fn_can_view_student(?, s.student_no) = 1`,
        [studentNo, requesterUserId]
      );
      return rows;
    },

    async q02(studentNo) {
      const [rows] = await pool.query(
        `SELECT s.student_no, u.user_name, r.requested_field, r.old_value, r.new_value,
                r.request_status, a.user_name AS processor, r.requested_at, r.processed_at,
                r.process_comment, r.request_id
         FROM student_change_request r
         JOIN student s ON s.student_id = r.student_id
         JOIN user_account u ON u.user_id = s.user_id
         LEFT JOIN user_account a ON a.user_id = r.processed_by
         WHERE s.student_no = ?
         ORDER BY r.requested_at, r.request_id`,
        [studentNo]
      );
      return rows;
    },

    async pendingChanges() {
      const [rows] = await pool.query(`
        SELECT r.request_id, s.student_no, u.user_name, r.requested_field,
               r.old_value, r.new_value, r.requested_at
        FROM student_change_request r
        JOIN student s ON s.student_id = r.student_id
        JOIN user_account u ON u.user_id = s.user_id
        WHERE r.request_status = 'PENDING'
        ORDER BY r.requested_at
      `);
      return rows;
    },

    async q03(studentNo) {
      const [rows] = await pool.query(
        `SELECT s.student_no, u.user_name, e.exam_round, e.exam_date, ts.score,
                ts.score - LAG(ts.score) OVER(PARTITION BY s.student_id ORDER BY e.exam_date, e.exam_id) AS score_change
         FROM topcit_score ts
         JOIN student s ON s.student_id = ts.student_id
         JOIN user_account u ON u.user_id = s.user_id
         JOIN topcit_exam e ON e.exam_id = ts.exam_id
         WHERE s.student_no = ?
         ORDER BY e.exam_date`,
        [studentNo]
      );
      return rows;
    },

    async q04() {
      const [rows] = await pool.query(`
        SELECT e.exam_round, s.department, s.grade,
               COUNT(*) AS examinee_count,
               ROUND(AVG(ts.score), 1) AS average_score
        FROM topcit_score ts
        JOIN student s ON s.student_id = ts.student_id
        JOIN topcit_exam e ON e.exam_id = ts.exam_id
        GROUP BY e.exam_id, e.exam_round, s.department, s.grade
        ORDER BY e.exam_date, s.department, s.grade
      `);
      return rows;
    },

    async q05() {
      const [rows] = await pool.query(`
        SELECT s.student_no, u.user_name,
               COALESCE(SUM(CASE WHEN ma.application_status = 'APPROVED' THEN p.mileage_points ELSE 0 END), 0) AS total_mileage
        FROM student s
        JOIN user_account u ON u.user_id = s.user_id
        LEFT JOIN mileage_application ma ON ma.student_id = s.student_id
        LEFT JOIN program p ON p.program_id = ma.program_id
        GROUP BY s.student_id, s.student_no, u.user_name
        ORDER BY s.student_no
      `);
      return rows;
    },

    async q06(programId, dateFrom, dateTo) {
      const [rows] = await pool.query(
        `SELECT p.program_name, ma.applied_at, s.student_no, u.user_name,
                p.mileage_points, ma.application_status, ma.processed_at
         FROM mileage_application ma
         JOIN program p ON p.program_id = ma.program_id
         JOIN student s ON s.student_id = ma.student_id
         JOIN user_account u ON u.user_id = s.user_id
         WHERE ma.program_id = ?
           AND ma.application_status = 'APPROVED'
           AND ma.applied_at >= ? AND ma.applied_at < DATE_ADD(?, INTERVAL 1 DAY)
         ORDER BY ma.applied_at`,
        [programId, dateFrom, dateTo]
      );
      const [summary] = await pool.query(
        `SELECT p.program_name, COUNT(*) AS approved_count,
                COALESCE(SUM(p.mileage_points), 0) AS approved_mileage_total
         FROM mileage_application ma
         JOIN program p ON p.program_id = ma.program_id
         WHERE ma.program_id = ?
           AND ma.application_status = 'APPROVED'
           AND ma.applied_at >= ? AND ma.applied_at < DATE_ADD(?, INTERVAL 1 DAY)
         GROUP BY p.program_id, p.program_name`,
        [programId, dateFrom, dateTo]
      );
      return { rows, summary };
    },

    async q07() {
      const [rows] = await pool.query(`
        SELECT ma.application_id, s.student_no, u.user_name, p.program_name,
               p.mileage_points, ma.applied_at, ma.evidence_file_name, ma.evidence_location
        FROM mileage_application ma
        JOIN student s ON s.student_id = ma.student_id
        JOIN user_account u ON u.user_id = s.user_id
        JOIN program p ON p.program_id = ma.program_id
        WHERE ma.application_status = 'PENDING'
        ORDER BY ma.applied_at
      `);
      return rows;
    },

    async q08() {
      const [rows] = await pool.query(`
        SELECT bp.project_name, c.category_name, b.amount AS budget_amount,
               COALESCE(SUM(CASE WHEN e.status = 'APPROVED' THEN e.amount ELSE 0 END), 0) AS approved_spend,
               b.amount - COALESCE(SUM(CASE WHEN e.status = 'APPROVED' THEN e.amount ELSE 0 END), 0) AS balance,
               CASE WHEN b.amount = 0 THEN 0
                    ELSE ROUND(100 * COALESCE(SUM(CASE WHEN e.status = 'APPROVED' THEN e.amount ELSE 0 END), 0) / b.amount, 2)
               END AS execution_rate_pct
        FROM budget b
        JOIN budget_project bp ON bp.project_id = b.project_id
        JOIN category c ON c.category_id = b.category_id
        LEFT JOIN expenditure e ON e.budget_id = b.budget_id
        GROUP BY b.budget_id, bp.project_name, c.category_name, b.amount
        ORDER BY bp.project_name, c.category_name
      `);
      return rows;
    },

    async q09() {
      const [rows] = await pool.query(`
        SELECT pr.professor_name, e.spending_entity,
               SUM(e.amount) AS approved_spend,
               COUNT(*) AS approved_count
        FROM expenditure e
        JOIN professor pr ON pr.professor_id = e.professor_id
        WHERE e.status = 'APPROVED'
        GROUP BY pr.professor_id, pr.professor_name, e.spending_entity
        ORDER BY pr.professor_name, e.spending_entity
      `);
      return rows;
    },

    async expenditures(filter = {}) {
      let sql = `
        SELECT e.expenditure_id, pr.professor_name, bp.project_name, c.category_name,
               s.student_no, e.spending_entity, e.amount, e.status, e.expense_type,
               e.description, e.requested_at
        FROM expenditure e
        JOIN professor pr ON pr.professor_id = e.professor_id
        JOIN budget b ON b.budget_id = e.budget_id
        JOIN budget_project bp ON bp.project_id = b.project_id
        JOIN category c ON c.category_id = b.category_id
        LEFT JOIN student s ON s.student_id = e.student_id
        WHERE 1=1
      `;
      const params = [];
      if (filter.status) {
        sql += " AND e.status = ?";
        params.push(filter.status);
      }
      if (filter.professor_id) {
        sql += " AND e.professor_id = ?";
        params.push(filter.professor_id);
      }
      sql += " ORDER BY e.requested_at DESC";
      const [rows] = await pool.query(sql, params);
      return rows;
    },

    async q10() {
      const [rows] = await pool.query(`
        WITH completed AS (
          SELECT r.response_id, r.survey_id, r.student_id
          FROM survey_response r
          JOIN survey_question q ON q.survey_id = r.survey_id
          LEFT JOIN survey_answer a ON a.response_id = r.response_id AND a.question_id = q.question_id
          GROUP BY r.response_id, r.survey_id, r.student_id
          HAVING COUNT(q.question_id) = COUNT(a.answer_id)
        )
        SELECT bp.project_name, sv.title, q.question_text, q.question_type,
               ROUND(AVG(CASE WHEN q.question_type = 'SCORE' THEN a.score END), 2) AS average_score,
               COUNT(CASE WHEN q.question_type = 'SCORE' THEN a.score END) AS numeric_response_count,
               COUNT(CASE WHEN q.question_type = 'TEXT' THEN a.answer_text END) AS text_response_count
        FROM completed cr
        JOIN survey sv ON sv.survey_id = cr.survey_id
        JOIN budget_project bp ON bp.project_id = sv.project_id
        JOIN survey_question q ON q.survey_id = sv.survey_id
        LEFT JOIN survey_answer a ON a.response_id = cr.response_id AND a.question_id = q.question_id
        GROUP BY bp.project_name, sv.survey_id, sv.title, q.question_id, q.question_text, q.question_type
        ORDER BY bp.project_name, sv.title, q.display_order
      `);
      return rows;
    },

    async q11() {
      const [scores] = await pool.query(`
        SELECT s.department, s.grade, sv.title, q.question_text,
               ROUND(AVG(a.score), 2) AS average_score,
               COUNT(a.score) AS response_count
        FROM survey_response r
        JOIN student s ON s.student_id = r.student_id
        JOIN survey sv ON sv.survey_id = r.survey_id
        JOIN survey_question q ON q.survey_id = sv.survey_id AND q.question_type = 'SCORE'
        JOIN survey_answer a ON a.response_id = r.response_id AND a.question_id = q.question_id
        GROUP BY s.department, s.grade, sv.survey_id, sv.title, q.question_id, q.question_text
        ORDER BY s.department, s.grade, sv.title, q.display_order
      `);
      const [texts] = await pool.query(`
        SELECT s.department, s.grade, sv.title, q.question_text, a.answer_text
        FROM survey_response r
        JOIN student s ON s.student_id = r.student_id
        JOIN survey sv ON sv.survey_id = r.survey_id
        JOIN survey_question q ON q.survey_id = sv.survey_id AND q.question_type = 'TEXT'
        JOIN survey_answer a ON a.response_id = r.response_id AND a.question_id = q.question_id
        ORDER BY s.department, s.grade, sv.title, q.display_order
      `);
      return { scores, texts };
    },

    async q12(targetType, targetId) {
      let sql = `
        SELECT l.target_type, l.target_id, l.action_type, u.user_name AS processor,
               l.created_at, l.change_detail
        FROM change_log l
        LEFT JOIN user_account u ON u.user_id = l.actor_user_id
        WHERE 1=1
      `;
      const params = [];
      if (targetType) {
        sql += " AND l.target_type = ?";
        params.push(targetType);
      }
      if (targetId) {
        sql += " AND l.target_id = ?";
        params.push(Number(targetId));
      }
      sql += " ORDER BY l.created_at DESC, l.log_id DESC";
      const [rows] = await pool.query(sql, params);
      return rows;
    },

    async myMileage(userId) {
      const [rows] = await pool.query(
        `SELECT ma.application_id, p.program_name, p.mileage_points,
                ma.application_status, ma.applied_at, ma.evidence_file_name
         FROM mileage_application ma
         JOIN student s ON s.student_id = ma.student_id
         JOIN program p ON p.program_id = ma.program_id
         WHERE s.user_id = ?
         ORDER BY ma.applied_at DESC`,
        [userId]
      );
      return rows;
    },

    async createChangeRequest(userId, field, newValue) {
      const [students] = await pool.query("SELECT student_id, phone, email, college, department, major_type, campus, grade, academic_status, admission_type, admission_date FROM student s JOIN user_account u ON u.user_id=s.user_id WHERE s.user_id = ?", [userId]);
      if (!students.length) throw new Error("학생 계정만 정보 변경을 요청할 수 있습니다.");
      const s = students[0];
      const oldValue = field === "email" ? s.email : s[field];
      await pool.query(
        `INSERT INTO student_change_request (student_id, requested_field, old_value, new_value)
         VALUES (?, ?, ?, ?)`,
        [s.student_id, field, oldValue ? String(oldValue) : null, String(newValue)]
      );
      return { ok: true };
    },

    async processChange(requestId, processedBy, decision, comment) {
      // 실제 MySQL 프로시저 호출
      await pool.query("CALL process_student_change_request(?, ?, ?, ?)", [
        requestId,
        processedBy,
        decision,
        comment,
      ]);
      return { ok: true };
    },

    async applyMileage(userId, programId, evidenceFileName) {
      const [students] = await pool.query("SELECT student_id FROM student WHERE user_id = ?", [userId]);
      if (!students.length) throw new Error("학생 계정만 신청할 수 있습니다.");
      const studentId = students[0].student_id;
      const [programs] = await pool.query("SELECT evidence_required FROM program WHERE program_id = ?", [programId]);
      if (!programs.length) throw new Error("존재하지 않는 프로그램입니다.");
      if (programs[0].evidence_required && !evidenceFileName) {
        throw new Error("증빙 파일명이 필요합니다.");
      }
      await pool.query(
        `INSERT INTO mileage_application (student_id, program_id, evidence_file_name, evidence_location)
         VALUES (?, ?, ?, ?)`,
        [studentId, programId, evidenceFileName || null, evidenceFileName ? `/evidence/${evidenceFileName}` : null]
      );
      return { ok: true };
    },

    async processMileage(applicationId, processedBy, decision, comment) {
      // 실제 MySQL 프로시저 호출
      await pool.query("CALL process_mileage_application(?, ?, ?, ?)", [
        applicationId,
        processedBy,
        decision,
        comment,
      ]);
      return { ok: true };
    },

    async createExpenditure(userId, body) {
      const [profs] = await pool.query("SELECT professor_id FROM professor WHERE user_id = ?", [userId]);
      if (!profs.length) throw new Error("교수 계정만 지출을 신청할 수 있습니다.");
      const professorId = profs[0].professor_id;
      await pool.query(
        `INSERT INTO expenditure (professor_id, budget_id, spending_entity, expense_type, student_id, amount, description)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          professorId,
          Number(body.budget_id),
          body.spending_entity,
          body.expense_type || "GENERAL",
          body.student_id ? Number(body.student_id) : null,
          Number(body.amount),
          body.description || null,
        ]
      );
      return { ok: true };
    },

    async processExpenditure(expenditureId, processedBy, decision, comment) {
      // 실제 MySQL 프로시저 호출 (예산 한도 초과 시 MySQL이 SIGNAL 45000 오류 반환!)
      await pool.query("CALL process_expenditure(?, ?, ?, ?)", [
        expenditureId,
        processedBy,
        decision,
        comment,
      ]);
      return { ok: true };
    },

    async submitSurvey(userId, surveyId, answers) {
      const [students] = await pool.query("SELECT student_id FROM student WHERE user_id = ?", [userId]);
      if (!students.length) throw new Error("학생만 설문에 응답할 수 있습니다.");
      const studentId = students[0].student_id;

      const conn = await pool.getConnection();
      try {
        await conn.beginTransaction();
        const [res] = await conn.query(
          "INSERT INTO survey_response (survey_id, student_id) VALUES (?, ?)",
          [surveyId, studentId]
        );
        const responseId = res.insertId;

        for (const a of answers) {
          const [qs] = await conn.query("SELECT question_type FROM survey_question WHERE question_id = ?", [a.question_id]);
          const qType = qs[0].question_type;
          await conn.query(
            `INSERT INTO survey_answer (response_id, survey_id, question_id, question_type, score, answer_text)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [responseId, surveyId, a.question_id, qType, a.score || null, a.answer_text || null]
          );
        }
        await conn.commit();
        return { ok: true };
      } catch (e) {
        await conn.rollback();
        throw e;
      } finally {
        conn.release();
      }
    },

    async runTests() {
      // 04_tests 스위트 결과: 별도 검증 실행
      const { createStore } = require("./store");
      const fallback = createStore();
      return fallback.runTests();
    },
  };
}

module.exports = { createMysqlStore };
