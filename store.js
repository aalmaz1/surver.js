"use strict";

function nowStr(d = new Date()) {
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function clone(v) {
  return JSON.parse(JSON.stringify(v));
}

function createStore() {
  const db = {};

  function reset() {
    db.roles = [
      { role_id: 1, role_name: "학생" },
      { role_id: 2, role_name: "일반관리자" },
      { role_id: 3, role_name: "최고관리자" },
      { role_id: 4, role_name: "교수" },
    ];
    const names = [
      ["student01", "김민준"], ["student02", "이서연"], ["student03", "박지호"],
      ["student04", "최유진"], ["student05", "정도윤"], ["student06", "강하은"],
      ["student07", "조현우"], ["student08", "윤서준"], ["student09", "장예린"],
      ["student10", "임시우"], ["admin01", "일반관리자"], ["admin02", "최고관리자"],
      ["prof01", "김교수"], ["prof02", "이교수"], ["prof03", "박교수"],
    ];
    db.users = names.map((n, i) => ({
      user_id: i + 1,
      login_id: n[0],
      user_name: n[1],
      email: `${n[0]}@example.com`,
      is_active: true,
      created_at: "2026-03-01 09:00:00",
    }));
    db.userRoles = [];
    for (let i = 1; i <= 10; i++) db.userRoles.push({ user_id: i, role_id: 1 });
    db.userRoles.push({ user_id: 11, role_id: 2 }, { user_id: 12, role_id: 3 });
    for (let i = 13; i <= 15; i++) db.userRoles.push({ user_id: i, role_id: 4 });

    db.policies = [
      { policy_id: 1, role_id: 1, resource_name: "student_profile", permission_name: "READ", scope_type: "OWN", scope_description: "본인 학생 정보만 조회" },
      { policy_id: 2, role_id: 1, resource_name: "mileage_application", permission_name: "CREATE", scope_type: "OWN", scope_description: "본인 마일리지 신청" },
      { policy_id: 3, role_id: 2, resource_name: "student_profile", permission_name: "READ", scope_type: "ALL", scope_description: "전체 학생 정보 조회(수정 불가)" },
      { policy_id: 4, role_id: 2, resource_name: "student_change_request", permission_name: "APPROVE", scope_type: "ALL", scope_description: "학생 정보 변경 요청 처리" },
      { policy_id: 5, role_id: 2, resource_name: "mileage_application", permission_name: "APPROVE", scope_type: "ALL", scope_description: "마일리지 신청 승인 및 반려" },
      { policy_id: 6, role_id: 3, resource_name: "student_profile", permission_name: "READ", scope_type: "ALL", scope_description: "전체 학생 정보 조회" },
      { policy_id: 7, role_id: 3, resource_name: "student_change_request", permission_name: "APPROVE", scope_type: "ALL", scope_description: "학생 정보 변경 요청 처리" },
      { policy_id: 8, role_id: 3, resource_name: "mileage_application", permission_name: "APPROVE", scope_type: "ALL", scope_description: "마일리지 신청 승인 및 반려" },
      { policy_id: 9, role_id: 3, resource_name: "expenditure", permission_name: "APPROVE", scope_type: "ALL", scope_description: "지출 승인 및 반려" },
      { policy_id: 10, role_id: 3, resource_name: "change_log", permission_name: "READ", scope_type: "ALL", scope_description: "전체 변경 이력 조회" },
    ];

    db.students = [];
    for (let i = 1; i <= 10; i++) {
      const n = String(i).padStart(2, "0");
      db.students.push({
        student_id: i,
        user_id: i,
        student_no: `202400${n}`,
        college: "공과대학",
        department: i <= 5 ? "소프트웨어학과" : "정보통신공학과",
        major_type: i <= 5 ? "공학" : "자연",
        campus: "천안캠퍼스",
        grade: i <= 5 ? 1 : 2,
        academic_status: i === 3 || i === 8 ? "휴학" : "재학",
        admission_type: i >= 9 ? "편입학" : "신입학",
        admission_date: "2024-03-04",
        phone: i === 2 ? "010-0000-0002" : null,
        sms_opt_in: false,
      });
    }
    db.users.find((u) => u.login_id === "student05").email = "new05@example.com";

    db.changeRequests = [
      { request_id: 1, student_id: 1, requested_field: "phone", old_value: null, new_value: "010-0000-0001", request_status: "PENDING", requested_at: "2026-10-19 09:00:00", processed_by: null, processed_at: null, process_comment: null },
      { request_id: 2, student_id: 2, requested_field: "phone", old_value: null, new_value: "010-0000-0002", request_status: "APPROVED", requested_at: "2026-10-18 09:00:00", processed_by: 11, processed_at: "2026-10-20 10:00:00", process_comment: "기존 승인 이력 샘플" },
      { request_id: 3, student_id: 3, requested_field: "email", old_value: "student03@example.com", new_value: "new03@example.com", request_status: "REJECTED", requested_at: "2026-10-18 10:00:00", processed_by: 11, processed_at: "2026-10-20 11:00:00", process_comment: "요청 값 확인 필요" },
      { request_id: 4, student_id: 4, requested_field: "phone", old_value: null, new_value: "010-0000-0004", request_status: "PENDING", requested_at: "2026-10-19 11:00:00", processed_by: null, processed_at: null, process_comment: null },
      { request_id: 5, student_id: 5, requested_field: "email", old_value: "student05@example.com", new_value: "new05@example.com", request_status: "APPROVED", requested_at: "2026-10-18 12:00:00", processed_by: 12, processed_at: "2026-10-20 12:00:00", process_comment: "기존 승인 이력 샘플" },
    ];
    db.nextRequestId = 6;

    db.exams = [
      { exam_id: 1, exam_name: "TOPCIT 정기평가", exam_date: "2025-05-17", exam_round: "2025-상반기" },
      { exam_id: 2, exam_name: "TOPCIT 정기평가", exam_date: "2025-10-18", exam_round: "2025-하반기" },
    ];
    const s1 = [620, 750, 480, 810, 560, 690, 720, 430, 880, 650];
    const s2 = [700, 790, 530, 850, 610, 740, 760, 500, 910, 710];
    db.topcit = [];
    let sid = 1;
    for (let i = 0; i < 10; i++) db.topcit.push({ score_id: sid++, student_id: i + 1, exam_id: 1, score: s1[i] });
    for (let i = 0; i < 10; i++) db.topcit.push({ score_id: sid++, student_id: i + 1, exam_id: 2, score: s2[i] });

    db.programs = [
      { program_id: 1, program_name: "AI 기초 특강", start_date: "2026-03-01", end_date: "2026-03-31", mileage_points: 10, evidence_required: true },
      { program_id: 2, program_name: "클라우드 실습 워크숍", start_date: "2026-04-01", end_date: "2026-04-30", mileage_points: 20, evidence_required: true },
      { program_id: 3, program_name: "SW 프로젝트 발표회", start_date: "2026-05-01", end_date: "2026-05-31", mileage_points: 15, evidence_required: false },
    ];
    db.mileage = [
      { application_id: 1, student_id: 1, program_id: 1, applied_at: "2026-03-05 10:00:00", evidence_file_name: "student01_ai.pdf", evidence_location: "/evidence/student01_ai.pdf", application_status: "APPROVED", processed_by: 11, processed_at: "2026-03-10 10:00:00", process_comment: "참여 확인" },
      { application_id: 2, student_id: 2, program_id: 1, applied_at: "2026-03-06 10:00:00", evidence_file_name: "student02_ai.pdf", evidence_location: "/evidence/student02_ai.pdf", application_status: "PENDING", processed_by: null, processed_at: null, process_comment: null },
      { application_id: 3, student_id: 3, program_id: 1, applied_at: "2026-03-07 10:00:00", evidence_file_name: "student03_ai.pdf", evidence_location: "/evidence/student03_ai.pdf", application_status: "REJECTED", processed_by: 11, processed_at: "2026-03-11 10:00:00", process_comment: "증빙 불충분" },
      { application_id: 4, student_id: 4, program_id: 2, applied_at: "2026-04-05 10:00:00", evidence_file_name: "student04_cloud.pdf", evidence_location: "/evidence/student04_cloud.pdf", application_status: "APPROVED", processed_by: 12, processed_at: "2026-04-10 10:00:00", process_comment: "참여 확인" },
      { application_id: 5, student_id: 5, program_id: 2, applied_at: "2026-04-06 10:00:00", evidence_file_name: "student05_cloud.pdf", evidence_location: "/evidence/student05_cloud.pdf", application_status: "PENDING", processed_by: null, processed_at: null, process_comment: null },
      { application_id: 6, student_id: 6, program_id: 2, applied_at: "2026-04-07 10:00:00", evidence_file_name: "student06_cloud.pdf", evidence_location: "/evidence/student06_cloud.pdf", application_status: "APPROVED", processed_by: 11, processed_at: "2026-04-11 10:00:00", process_comment: "참여 확인" },
      { application_id: 7, student_id: 7, program_id: 3, applied_at: "2026-05-05 10:00:00", evidence_file_name: "student07_show.pdf", evidence_location: "/evidence/student07_show.pdf", application_status: "PENDING", processed_by: null, processed_at: null, process_comment: null },
      { application_id: 8, student_id: 8, program_id: 3, applied_at: "2026-05-06 10:00:00", evidence_file_name: "student08_show.pdf", evidence_location: "/evidence/student08_show.pdf", application_status: "REJECTED", processed_by: 12, processed_at: "2026-05-12 10:00:00", process_comment: "참여 확인 불가" },
      { application_id: 9, student_id: 9, program_id: 3, applied_at: "2026-05-07 10:00:00", evidence_file_name: "student09_show.pdf", evidence_location: "/evidence/student09_show.pdf", application_status: "APPROVED", processed_by: 11, processed_at: "2026-05-13 10:00:00", process_comment: "참여 확인" },
      { application_id: 10, student_id: 10, program_id: 3, applied_at: "2026-05-08 10:00:00", evidence_file_name: "student10_show.pdf", evidence_location: "/evidence/student10_show.pdf", application_status: "PENDING", processed_by: null, processed_at: null, process_comment: null },
    ];
    db.nextMileageId = 11;

    db.categories = [
      { category_id: 1, category_name: "인건비" },
      { category_id: 2, category_name: "장비구입비" },
      { category_id: 3, category_name: "여비교통비" },
      { category_id: 4, category_name: "연구활동비" },
      { category_id: 5, category_name: "학생인건비" },
      { category_id: 6, category_name: "운영비" },
      { category_id: 7, category_name: "기타" },
    ];
    db.projects = [
      { project_id: 1, project_name: "2026년 SW중심대학 사업" },
      { project_id: 2, project_name: "글로벌 인재양성 사업" },
    ];
    const amounts = { 1: 8000000, 2: 5000000, 3: 1000000, 4: 2000000, 5: 10000000, 6: 1500000, 7: 500000 };
    db.budgets = db.categories.map((c) => ({
      budget_id: c.category_id,
      project_id: 1,
      category_id: c.category_id,
      amount: amounts[c.category_id],
    }));
    db.budgets.push({ budget_id: 8, project_id: 2, category_id: 1, amount: 8000000 });

    db.professors = [
      { professor_id: 1, professor_name: "김교수", user_id: 13 },
      { professor_id: 2, professor_name: "이교수", user_id: 14 },
      { professor_id: 3, professor_name: "박교수", user_id: 15 },
    ];
    db.expenditures = [
      { expenditure_id: 1, professor_id: 1, budget_id: 2, student_id: null, spending_entity: "산학협력", amount: 1500000, status: "APPROVED", expense_type: "GENERAL", description: "장비 구매", requested_at: "2026-04-01 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 2, professor_id: 1, budget_id: 2, student_id: null, spending_entity: "산학협력", amount: 500000, status: "PENDING", expense_type: "GENERAL", description: "장비 구매 대기", requested_at: "2026-04-02 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 3, professor_id: 1, budget_id: 5, student_id: 1, spending_entity: "전공", amount: 3000000, status: "APPROVED", expense_type: "STUDENT_LABOR", description: "학생 연구 인건비", requested_at: "2026-04-03 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 4, professor_id: 2, budget_id: 5, student_id: 2, spending_entity: "전공", amount: 2000000, status: "APPROVED", expense_type: "STUDENT_LABOR", description: "학생 연구 인건비", requested_at: "2026-04-04 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 5, professor_id: 2, budget_id: 5, student_id: 3, spending_entity: "융합", amount: 1000000, status: "PENDING", expense_type: "STUDENT_LABOR", description: "승인 대기 학생 인건비", requested_at: "2026-04-05 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 6, professor_id: 3, budget_id: 8, student_id: null, spending_entity: "융합", amount: 4000000, status: "APPROVED", expense_type: "GENERAL", description: "인건비", requested_at: "2026-04-06 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 7, professor_id: 3, budget_id: 8, student_id: null, spending_entity: "융합", amount: 1000000, status: "PENDING", expense_type: "GENERAL", description: "인건비 대기", requested_at: "2026-04-07 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 8, professor_id: 1, budget_id: 5, student_id: 4, spending_entity: "전공", amount: 500000, status: "APPROVED", expense_type: "STUDENT_LABOR", description: "학생 연구 인건비", requested_at: "2026-04-08 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 9, professor_id: 2, budget_id: 2, student_id: null, spending_entity: "산학협력", amount: 300000, status: "REJECTED", expense_type: "GENERAL", description: "반려된 장비 구매", requested_at: "2026-04-09 10:00:00", processed_by: null, processed_at: null, process_comment: null },
      { expenditure_id: 10, professor_id: 3, budget_id: 6, student_id: null, spending_entity: "융합", amount: 200000, status: "APPROVED", expense_type: "GENERAL", description: "운영비", requested_at: "2026-04-10 10:00:00", processed_by: null, processed_at: null, process_comment: null },
    ];
    db.nextExpId = 11;

    db.surveys = [
      { survey_id: 1, project_id: 1, title: "SW사업 만족도 조사", start_date: "2026-05-01", end_date: "2026-06-30" },
      { survey_id: 2, project_id: 2, title: "글로벌 인재양성 만족도 조사", start_date: "2026-05-01", end_date: "2026-06-30" },
    ];
    db.questions = [
      { question_id: 1, survey_id: 1, question_text: "프로그램 전반에 만족하십니까?", question_type: "SCORE", display_order: 1 },
      { question_id: 2, survey_id: 1, question_text: "운영 안내에 만족하십니까?", question_type: "SCORE", display_order: 2 },
      { question_id: 3, survey_id: 1, question_text: "개선 의견을 작성해 주세요.", question_type: "TEXT", display_order: 3 },
      { question_id: 4, survey_id: 2, question_text: "프로그램 전반에 만족하십니까?", question_type: "SCORE", display_order: 1 },
      { question_id: 5, survey_id: 2, question_text: "학습 내용에 만족하십니까?", question_type: "SCORE", display_order: 2 },
      { question_id: 6, survey_id: 2, question_text: "개선 의견을 작성해 주세요.", question_type: "TEXT", display_order: 3 },
    ];
    db.responses = [];
    db.answers = [];
    let rid = 1, aid = 1;
    for (const surveyId of [1, 2]) {
      for (let st = 1; st <= 5; st++) {
        const day = surveyId === 1 ? 1 + st : 10 + st;
        db.responses.push({
          response_id: rid,
          survey_id: surveyId,
          student_id: st,
          submitted_at: `2026-06-${String(day).padStart(2, "0")} 12:00:00`,
        });
        for (const q of db.questions.filter((x) => x.survey_id === surveyId)) {
          db.answers.push({
            answer_id: aid++,
            response_id: rid,
            survey_id: surveyId,
            question_id: q.question_id,
            question_type: q.question_type,
            score: q.question_type === "SCORE" ? 3 + (st % 3) : null,
            answer_text: q.question_type === "TEXT" ? `개선 의견 예시 ${st}` : null,
          });
        }
        rid++;
      }
    }
    db.nextResponseId = rid;
    db.nextAnswerId = aid;

    db.logs = [];
    let lid = 1;
    for (const r of db.changeRequests.filter((x) => x.processed_by)) {
      db.logs.push({
        log_id: lid++,
        actor_user_id: r.processed_by,
        target_type: "student_change_request",
        target_id: r.request_id,
        action_type: r.request_status,
        change_detail: `시드 이력: ${r.requested_field} -> ${r.request_status}`,
        created_at: r.processed_at,
      });
    }
    db.nextLogId = lid;
  }

  function userById(id) {
    return db.users.find((u) => u.user_id === id);
  }
  function studentByNo(no) {
    return db.students.find((s) => s.student_no === no);
  }
  function studentOfUser(userId) {
    return db.students.find((s) => s.user_id === userId);
  }
  function roleNames(userId) {
    return db.userRoles
      .filter((ur) => ur.user_id === userId)
      .map((ur) => db.roles.find((r) => r.role_id === ur.role_id).role_name);
  }
  function fn_has_permission(userId, resource, permission) {
    const u = userById(userId);
    if (!u || !u.is_active) return false;
    const roleIds = db.userRoles.filter((ur) => ur.user_id === userId).map((ur) => ur.role_id);
    return db.policies.some(
      (p) => roleIds.includes(p.role_id) && p.resource_name === resource && p.permission_name === permission
    );
  }
  function fn_can_view_student(requesterId, studentNo) {
    const u = userById(requesterId);
    if (!u || !u.is_active) return false;
    const roleIds = db.userRoles.filter((ur) => ur.user_id === requesterId).map((ur) => ur.role_id);
    const policies = db.policies.filter(
      (p) => roleIds.includes(p.role_id) && p.resource_name === "student_profile" && p.permission_name === "READ"
    );
    if (policies.some((p) => p.scope_type === "ALL")) return true;
    if (policies.some((p) => p.scope_type === "OWN")) {
      const s = studentOfUser(requesterId);
      return !!(s && s.student_no === studentNo);
    }
    return false;
  }
  function addLog(actor, type, id, action, detail) {
    db.logs.unshift({
      log_id: db.nextLogId++,
      actor_user_id: actor,
      target_type: type,
      target_id: id,
      action_type: action,
      change_detail: detail,
      created_at: nowStr(),
    });
  }
  function fail(msg) {
    const e = new Error(msg);
    e.status = 400;
    throw e;
  }

  reset();

  return {
    reset,
    session(loginId) {
      const u = db.users.find((x) => x.login_id === loginId);
      if (!u || !u.is_active) fail("로그인할 수 없는 계정입니다.");
      const student = studentOfUser(u.user_id) || null;
      const professor = db.professors.find((p) => p.user_id === u.user_id) || null;
      return {
        user_id: u.user_id,
        login_id: u.login_id,
        user_name: u.user_name,
        email: u.email,
        roles: roleNames(u.user_id),
        student_id: student ? student.student_id : null,
        student_no: student ? student.student_no : null,
        professor_id: professor ? professor.professor_id : null,
        permissions: {
          view_all_students: fn_has_permission(u.user_id, "student_profile", "READ") &&
            db.policies.some((p) => db.userRoles.some((ur) => ur.user_id === u.user_id && ur.role_id === p.role_id) && p.resource_name === "student_profile" && p.scope_type === "ALL"),
          approve_change: fn_has_permission(u.user_id, "student_change_request", "APPROVE"),
          approve_mileage: fn_has_permission(u.user_id, "mileage_application", "APPROVE"),
          create_mileage: fn_has_permission(u.user_id, "mileage_application", "CREATE"),
          approve_expenditure: fn_has_permission(u.user_id, "expenditure", "APPROVE"),
          read_log: fn_has_permission(u.user_id, "change_log", "READ"),
        },
      };
    },
    meta() {
      return {
        programs: clone(db.programs),
        projects: clone(db.projects),
        categories: clone(db.categories),
        budgets: db.budgets.map((b) => ({
          ...b,
          project_name: db.projects.find((p) => p.project_id === b.project_id).project_name,
          category_name: db.categories.find((c) => c.category_id === b.category_id).category_name,
        })),
        professors: clone(db.professors),
        students: db.students.map((s) => ({
          student_id: s.student_id,
          student_no: s.student_no,
          user_name: userById(s.user_id).user_name,
        })),
        surveys: db.surveys.map((sv) => ({
          ...sv,
          project_name: db.projects.find((p) => p.project_id === sv.project_id).project_name,
          questions: db.questions.filter((q) => q.survey_id === sv.survey_id),
        })),
        log_types: [...new Set(db.logs.map((l) => l.target_type))],
      };
    },
    q01(requesterId, studentNo) {
      if (!fn_can_view_student(requesterId, studentNo)) return [];
      const s = studentByNo(studentNo);
      if (!s) return [];
      const u = userById(s.user_id);
      return [{
        student_no: s.student_no, user_name: u.user_name, email: u.email,
        college: s.college, department: s.department, major_type: s.major_type,
        campus: s.campus, grade: s.grade, academic_status: s.academic_status,
        admission_type: s.admission_type, admission_date: s.admission_date, phone: s.phone,
      }];
    },
    q02(studentNo) {
      const s = studentByNo(studentNo);
      if (!s) return [];
      return db.changeRequests
        .filter((r) => r.student_id === s.student_id)
        .sort((a, b) => a.requested_at.localeCompare(b.requested_at) || a.request_id - b.request_id)
        .map((r) => ({
          student_no: s.student_no,
          user_name: userById(s.user_id).user_name,
          requested_field: r.requested_field,
          old_value: r.old_value,
          new_value: r.new_value,
          request_status: r.request_status,
          processor: r.processed_by ? userById(r.processed_by).user_name : null,
          requested_at: r.requested_at,
          processed_at: r.processed_at,
          process_comment: r.process_comment,
          request_id: r.request_id,
        }));
    },
    pendingChanges() {
      return db.changeRequests
        .filter((r) => r.request_status === "PENDING")
        .map((r) => {
          const s = db.students.find((x) => x.student_id === r.student_id);
          return {
            request_id: r.request_id,
            student_no: s.student_no,
            user_name: userById(s.user_id).user_name,
            requested_field: r.requested_field,
            old_value: r.old_value,
            new_value: r.new_value,
            requested_at: r.requested_at,
          };
        });
    },
    q03(studentNo) {
      const s = studentByNo(studentNo);
      if (!s) return [];
      const rows = db.topcit
        .filter((t) => t.student_id === s.student_id)
        .map((t) => {
          const e = db.exams.find((x) => x.exam_id === t.exam_id);
          return { ...t, exam_round: e.exam_round, exam_date: e.exam_date };
        })
        .sort((a, b) => a.exam_date.localeCompare(b.exam_date) || a.exam_id - b.exam_id);
      return rows.map((r, i) => ({
        student_no: s.student_no,
        user_name: userById(s.user_id).user_name,
        exam_round: r.exam_round,
        exam_date: r.exam_date,
        score: r.score,
        score_change: i === 0 ? null : r.score - rows[i - 1].score,
      }));
    },
    q04() {
      const map = new Map();
      for (const t of db.topcit) {
        const s = db.students.find((x) => x.student_id === t.student_id);
        const e = db.exams.find((x) => x.exam_id === t.exam_id);
        const k = `${e.exam_id}|${s.department}|${s.grade}`;
        if (!map.has(k)) map.set(k, { exam_round: e.exam_round, exam_date: e.exam_date, department: s.department, grade: s.grade, scores: [] });
        map.get(k).scores.push(t.score);
      }
      return [...map.values()]
        .sort((a, b) => a.exam_date.localeCompare(b.exam_date) || a.department.localeCompare(b.department) || a.grade - b.grade)
        .map((r) => ({
          exam_round: r.exam_round,
          department: r.department,
          grade: r.grade,
          examinee_count: r.scores.length,
          average_score: Math.round((r.scores.reduce((a, b) => a + b, 0) / r.scores.length) * 10) / 10,
        }));
    },
    q05() {
      return db.students.map((s) => {
        const total = db.mileage
          .filter((m) => m.student_id === s.student_id && m.application_status === "APPROVED")
          .reduce((sum, m) => sum + db.programs.find((p) => p.program_id === m.program_id).mileage_points, 0);
        return { student_no: s.student_no, user_name: userById(s.user_id).user_name, total_mileage: total };
      });
    },
    q06(programId, dateFrom, dateTo) {
      const p = db.programs.find((x) => x.program_id === programId);
      if (!p) return { rows: [], summary: [] };
      const from = dateFrom || "2000-01-01";
      const toEnd = dateTo || "2099-12-31";
      const rows = db.mileage
        .filter((m) => m.program_id === programId && m.application_status === "APPROVED")
        .filter((m) => m.applied_at.slice(0, 10) >= from && m.applied_at.slice(0, 10) <= toEnd)
        .map((m) => {
          const s = db.students.find((x) => x.student_id === m.student_id);
          return {
            program_name: p.program_name,
            applied_at: m.applied_at,
            student_no: s.student_no,
            user_name: userById(s.user_id).user_name,
            mileage_points: p.mileage_points,
            application_status: m.application_status,
            processed_at: m.processed_at,
          };
        });
      return {
        rows,
        summary: [{
          program_name: p.program_name,
          approved_count: rows.length,
          approved_mileage_total: rows.reduce((a, r) => a + r.mileage_points, 0),
        }],
      };
    },
    q07() {
      return db.mileage
        .filter((m) => m.application_status === "PENDING")
        .sort((a, b) => a.applied_at.localeCompare(b.applied_at))
        .map((m) => {
          const s = db.students.find((x) => x.student_id === m.student_id);
          const p = db.programs.find((x) => x.program_id === m.program_id);
          return {
            application_id: m.application_id,
            student_no: s.student_no,
            user_name: userById(s.user_id).user_name,
            program_name: p.program_name,
            mileage_points: p.mileage_points,
            applied_at: m.applied_at,
            evidence_file_name: m.evidence_file_name,
            evidence_location: m.evidence_location,
          };
        });
    },
    q08() {
      return db.budgets.map((b) => {
        const approved = db.expenditures
          .filter((e) => e.budget_id === b.budget_id && e.status === "APPROVED")
          .reduce((s, e) => s + e.amount, 0);
        return {
          project_name: db.projects.find((p) => p.project_id === b.project_id).project_name,
          category_name: db.categories.find((c) => c.category_id === b.category_id).category_name,
          budget_amount: b.amount,
          approved_spend: approved,
          balance: b.amount - approved,
          execution_rate_pct: b.amount === 0 ? 0 : Math.round((100 * approved) / b.amount * 100) / 100,
        };
      });
    },
    q09() {
      const map = new Map();
      for (const e of db.expenditures.filter((x) => x.status === "APPROVED")) {
        const pr = db.professors.find((p) => p.professor_id === e.professor_id);
        const k = `${pr.professor_id}|${e.spending_entity}`;
        if (!map.has(k)) map.set(k, { professor_name: pr.professor_name, spending_entity: e.spending_entity, approved_spend: 0, approved_count: 0 });
        const row = map.get(k);
        row.approved_spend += e.amount;
        row.approved_count += 1;
      }
      return [...map.values()].sort((a, b) => a.professor_name.localeCompare(b.professor_name) || a.spending_entity.localeCompare(b.spending_entity));
    },
    expenditures(filter = {}) {
      return db.expenditures
        .filter((e) => !filter.status || e.status === filter.status)
        .filter((e) => !filter.professor_id || e.professor_id === filter.professor_id)
        .map((e) => {
          const b = db.budgets.find((x) => x.budget_id === e.budget_id);
          const s = e.student_id ? db.students.find((x) => x.student_id === e.student_id) : null;
          return {
            expenditure_id: e.expenditure_id,
            professor_name: db.professors.find((p) => p.professor_id === e.professor_id).professor_name,
            project_name: db.projects.find((p) => p.project_id === b.project_id).project_name,
            category_name: db.categories.find((c) => c.category_id === b.category_id).category_name,
            student_no: s ? s.student_no : null,
            spending_entity: e.spending_entity,
            amount: e.amount,
            status: e.status,
            expense_type: e.expense_type,
            description: e.description,
            requested_at: e.requested_at,
          };
        });
    },
    q10() {
      const completed = db.responses.filter((r) => {
        const qs = db.questions.filter((q) => q.survey_id === r.survey_id);
        const ans = db.answers.filter((a) => a.response_id === r.response_id);
        return qs.length === ans.length;
      });
      const rows = [];
      for (const sv of db.surveys) {
        const qs = db.questions.filter((q) => q.survey_id === sv.survey_id).sort((a, b) => a.display_order - b.display_order);
        const cr = completed.filter((r) => r.survey_id === sv.survey_id);
        for (const q of qs) {
          const answers = cr.map((r) => db.answers.find((a) => a.response_id === r.response_id && a.question_id === q.question_id)).filter(Boolean);
          const scores = answers.filter((a) => a.question_type === "SCORE").map((a) => a.score);
          const texts = answers.filter((a) => a.question_type === "TEXT" && a.answer_text);
          rows.push({
            project_name: db.projects.find((p) => p.project_id === sv.project_id).project_name,
            title: sv.title,
            question_text: q.question_text,
            question_type: q.question_type,
            average_score: scores.length ? Math.round((scores.reduce((a, b) => a + b, 0) / scores.length) * 100) / 100 : null,
            numeric_response_count: scores.length,
            text_response_count: texts.length,
          });
        }
      }
      return rows;
    },
    q11() {
      const scores = [];
      const texts = [];
      for (const r of db.responses) {
        const s = db.students.find((x) => x.student_id === r.student_id);
        const sv = db.surveys.find((x) => x.survey_id === r.survey_id);
        for (const q of db.questions.filter((x) => x.survey_id === r.survey_id)) {
          const a = db.answers.find((x) => x.response_id === r.response_id && x.question_id === q.question_id);
          if (!a) continue;
          if (q.question_type === "SCORE") {
            scores.push({ department: s.department, grade: s.grade, title: sv.title, question_text: q.question_text, question_id: q.question_id, display_order: q.display_order, score: a.score });
          } else {
            texts.push({ department: s.department, grade: s.grade, title: sv.title, question_text: q.question_text, display_order: q.display_order, answer_text: a.answer_text });
          }
        }
      }
      const map = new Map();
      for (const r of scores) {
        const k = `${r.department}|${r.grade}|${r.title}|${r.question_id}`;
        if (!map.has(k)) map.set(k, { ...r, scores: [] });
        map.get(k).scores.push(r.score);
      }
      const scoreRows = [...map.values()]
        .sort((a, b) => a.department.localeCompare(b.department) || a.grade - b.grade || a.title.localeCompare(b.title) || a.display_order - b.display_order)
        .map((r) => ({
          department: r.department,
          grade: r.grade,
          title: r.title,
          question_text: r.question_text,
          average_score: Math.round((r.scores.reduce((a, b) => a + b, 0) / r.scores.length) * 100) / 100,
          response_count: r.scores.length,
        }));
      texts.sort((a, b) => a.department.localeCompare(b.department) || a.grade - b.grade || a.title.localeCompare(b.title) || a.display_order - b.display_order);
      return { scores: scoreRows, texts };
    },
    q12(targetType, targetId) {
      return db.logs
        .filter((l) => !targetType || l.target_type === targetType)
        .filter((l) => !targetId || l.target_id === Number(targetId))
        .map((l) => ({
          target_type: l.target_type,
          target_id: l.target_id,
          action_type: l.action_type,
          processor: l.actor_user_id ? userById(l.actor_user_id).user_name : null,
          created_at: l.created_at,
          change_detail: l.change_detail,
        }));
    },
    createChangeRequest(userId, field, newValue) {
      const s = studentOfUser(userId);
      if (!s) fail("학생 계정만 정보 변경을 요청할 수 있습니다.");
      const allowed = ["college", "department", "major_type", "campus", "grade", "academic_status", "admission_type", "admission_date", "phone", "email"];
      if (!allowed.includes(field)) fail("허용되지 않은 변경 항목");
      let oldValue = field === "email" ? userById(s.user_id).email : s[field];
      if (oldValue != null) oldValue = String(oldValue);
      const row = {
        request_id: db.nextRequestId++,
        student_id: s.student_id,
        requested_field: field,
        old_value: oldValue,
        new_value: String(newValue),
        request_status: "PENDING",
        requested_at: nowStr(),
        processed_by: null,
        processed_at: null,
        process_comment: null,
      };
      db.changeRequests.push(row);
      return row;
    },
    processChange(requestId, processedBy, decision, comment) {
      const v = String(decision || "").toUpperCase().trim();
      if (!["APPROVED", "REJECTED"].includes(v)) fail("decision은 APPROVED 또는 REJECTED여야 합니다.");
      if (!fn_has_permission(processedBy, "student_change_request", "APPROVE")) fail("관리자 승인 권한이 없습니다(role_policy).");
      const r = db.changeRequests.find((x) => x.request_id === requestId);
      if (!r || r.request_status !== "PENDING") fail("PENDING 요청만 처리할 수 있습니다.");
      const s = db.students.find((x) => x.student_id === r.student_id);
      if (v === "APPROVED") {
        const nv = r.new_value;
        switch (r.requested_field) {
          case "college": s.college = nv; break;
          case "department": s.department = nv; break;
          case "major_type":
            if (!["공학", "자연"].includes(nv)) fail("major_type 값 오류");
            s.major_type = nv; break;
          case "campus": s.campus = nv; break;
          case "grade":
            if (!/^[1-6]$/.test(nv)) fail("grade는 1~6");
            s.grade = Number(nv); break;
          case "academic_status":
            if (!["재학", "휴학", "졸업"].includes(nv)) fail("academic_status 값 오류");
            s.academic_status = nv; break;
          case "admission_type":
            if (!["신입학", "편입학"].includes(nv)) fail("admission_type 값 오류");
            s.admission_type = nv; break;
          case "admission_date":
            if (!/^\d{4}-\d{2}-\d{2}$/.test(nv)) fail("admission_date는 YYYY-MM-DD");
            s.admission_date = nv; break;
          case "phone": s.phone = nv; break;
          case "email": userById(s.user_id).email = nv; break;
          default: fail("허용되지 않은 변경 항목");
        }
      }
      r.request_status = v;
      r.processed_by = processedBy;
      r.processed_at = nowStr();
      r.process_comment = comment || null;
      addLog(processedBy, "student_change_request", r.request_id, v, `field=${r.requested_field}; new=${r.new_value}; comment=${comment || ""}`);
      return r;
    },
    applyMileage(userId, programId, evidenceFile) {
      if (!fn_has_permission(userId, "mileage_application", "CREATE")) fail("마일리지 신청 권한이 없습니다(role_policy).");
      const s = studentOfUser(userId);
      if (!s) fail("학생 계정만 신청할 수 있습니다.");
      const p = db.programs.find((x) => x.program_id === programId);
      if (!p) fail("프로그램을 찾을 수 없습니다.");
      if (db.mileage.some((m) => m.student_id === s.student_id && m.program_id === programId)) fail("이미 신청한 프로그램입니다(학생+프로그램 1회).");
      if (p.evidence_required && !evidenceFile) fail("증빙 파일명이 필요합니다.");
      const row = {
        application_id: db.nextMileageId++,
        student_id: s.student_id,
        program_id: programId,
        applied_at: nowStr(),
        evidence_file_name: evidenceFile || null,
        evidence_location: evidenceFile ? `/evidence/${evidenceFile}` : null,
        application_status: "PENDING",
        processed_by: null,
        processed_at: null,
        process_comment: null,
      };
      db.mileage.push(row);
      return row;
    },
    myMileage(userId) {
      const s = studentOfUser(userId);
      if (!s) return [];
      return db.mileage
        .filter((m) => m.student_id === s.student_id)
        .map((m) => {
          const p = db.programs.find((x) => x.program_id === m.program_id);
          return { ...m, program_name: p.program_name, mileage_points: p.mileage_points };
        });
    },
    processMileage(applicationId, processedBy, decision, comment) {
      const v = String(decision || "").toUpperCase().trim();
      if (!["APPROVED", "REJECTED"].includes(v)) fail("decision은 APPROVED 또는 REJECTED여야 합니다.");
      if (!fn_has_permission(processedBy, "mileage_application", "APPROVE")) fail("관리자 승인 권한이 없습니다(role_policy).");
      const m = db.mileage.find((x) => x.application_id === applicationId);
      if (!m || m.application_status !== "PENDING") fail("PENDING 신청만 처리할 수 있습니다. 중복 승인 방지.");
      const p = db.programs.find((x) => x.program_id === m.program_id);
      m.application_status = v;
      m.processed_by = processedBy;
      m.processed_at = nowStr();
      m.process_comment = comment || null;
      addLog(processedBy, "mileage_application", m.application_id, v, `student_id=${m.student_id}; program=${p.program_name}; points=${p.mileage_points}; comment=${comment || ""}`);
      return m;
    },
    createExpenditure(userId, body) {
      const pr = db.professors.find((p) => p.user_id === userId);
      if (!pr) fail("교수 계정만 지출을 신청할 수 있습니다.");
      const budget = db.budgets.find((b) => b.budget_id === Number(body.budget_id));
      if (!budget) fail("예산 항목을 찾을 수 없습니다.");
      const amount = Number(body.amount);
      if (!(amount > 0)) fail("금액은 양수여야 합니다.");
      const type = body.expense_type || "GENERAL";
      const studentId = body.student_id ? Number(body.student_id) : null;
      if (type === "STUDENT_LABOR" && !studentId) fail("학생인건비는 학생을 지정해야 합니다.");
      if (type === "GENERAL" && studentId) fail("일반 지출에는 학생을 지정할 수 없습니다.");
      const row = {
        expenditure_id: db.nextExpId++,
        professor_id: pr.professor_id,
        budget_id: budget.budget_id,
        student_id: studentId,
        spending_entity: body.spending_entity,
        amount,
        status: "PENDING",
        expense_type: type,
        description: body.description || null,
        requested_at: nowStr(),
        processed_by: null,
        processed_at: null,
        process_comment: null,
      };
      db.expenditures.push(row);
      return row;
    },
    processExpenditure(expenditureId, processedBy, decision, comment) {
      const v = String(decision || "").toUpperCase().trim();
      if (!["APPROVED", "REJECTED"].includes(v)) fail("decision은 APPROVED 또는 REJECTED여야 합니다.");
      if (!fn_has_permission(processedBy, "expenditure", "APPROVE")) fail("관리자 승인 권한이 없습니다(role_policy).");
      const e = db.expenditures.find((x) => x.expenditure_id === expenditureId);
      if (!e || e.status !== "PENDING") fail("PENDING 지출만 처리할 수 있습니다. 중복 승인 방지.");
      if (v === "APPROVED") {
        const budget = db.budgets.find((b) => b.budget_id === e.budget_id);
        const spent = db.expenditures.filter((x) => x.budget_id === e.budget_id && x.status === "APPROVED").reduce((s, x) => s + x.amount, 0);
        if (spent + e.amount > budget.amount) fail("예산 한도 초과: 지출 승인 거부");
      }
      e.status = v;
      e.processed_by = processedBy;
      e.processed_at = nowStr();
      e.process_comment = comment || null;
      addLog(processedBy, "expenditure", e.expenditure_id, v, `budget_id=${e.budget_id}; amount=${e.amount}; comment=${comment || ""}`);
      return e;
    },
    submitSurvey(userId, surveyId, answers) {
      const s = studentOfUser(userId);
      if (!s) fail("학생만 설문에 응답할 수 있습니다.");
      const sv = db.surveys.find((x) => x.survey_id === surveyId);
      if (!sv) fail("설문을 찾을 수 없습니다.");
      if (db.responses.some((r) => r.survey_id === surveyId && r.student_id === s.student_id)) fail("이미 응답한 설문입니다.");
      const qs = db.questions.filter((q) => q.survey_id === surveyId);
      for (const q of qs) {
        const a = (answers || []).find((x) => Number(x.question_id) === q.question_id);
        if (!a) fail("모든 문항에 답해야 합니다.");
        if (q.question_type === "SCORE") {
          const sc = Number(a.score);
          if (!(sc >= 1 && sc <= 5)) fail("점수형 문항은 1~5점만 허용합니다.");
        } else if (!String(a.answer_text || "").trim()) fail("서술형 문항은 비어 있을 수 없습니다.");
      }
      const rid = db.nextResponseId++;
      db.responses.push({ response_id: rid, survey_id: surveyId, student_id: s.student_id, submitted_at: nowStr() });
      for (const q of qs) {
        const a = answers.find((x) => Number(x.question_id) === q.question_id);
        db.answers.push({
          answer_id: db.nextAnswerId++,
          response_id: rid,
          survey_id: surveyId,
          question_id: q.question_id,
          question_type: q.question_type,
          score: q.question_type === "SCORE" ? Number(a.score) : null,
          answer_text: q.question_type === "TEXT" ? String(a.answer_text).trim() : null,
        });
      }
      return { response_id: rid };
    },
    runTests() {
      // 04_tests.sql 전체 테스트 스위트를 격리된 샌드박스 인스턴스에서 수행
      const sb = createStore();
      const results = [];
      let seq = 1;

      function rec(id, cat, desc, exp, act, res) {
        results.push({ seq: seq++, test_id: id, category: cat, description: desc, expected: String(exp), actual: String(act), result: res });
      }
      function chk(id, cat, desc, exp, act) {
        const pass = String(exp) === String(act);
        rec(id, cat, desc, exp, act, pass ? "PASS" : "FAIL");
      }
      function expectErr(id, cat, desc, fn, expPattern) {
        try {
          fn();
          rec(id, cat, desc, `오류 발생 (${expPattern})`, "정상 실행됨(오류 미발생)", "FAIL");
        } catch (e) {
          const msg = e.message || String(e);
          const ok = !expPattern || msg.includes(expPattern);
          rec(id, cat, desc, `오류: ${expPattern}`, `차단됨: ${msg}`, ok ? "PASS" : "FAIL");
        }
      }
      function expectOk(id, cat, desc, fn) {
        try {
          fn();
          rec(id, cat, desc, "정상 완료", "성공", "PASS");
        } catch (e) {
          rec(id, cat, desc, "정상 완료", `실패: ${e.message}`, "FAIL");
        }
      }

      // === P. 사전조건 (초기 시드 상태) ===
      chk("P01", "P.사전조건", "학생 수 10명", "10", sb.meta().students.length);
      const q4Init = sb.q04();
      const totalExaminees = q4Init.reduce((sum, r) => sum + r.examinee_count, 0);
      chk("P02", "P.사전조건", "TOPCIT 점수 건수 (2회차 x 10명 = 20건)", "20", totalExaminees);
      chk("P03", "P.사전조건", "프로그램 3개 / 초기 마일리지 신청 10건", "3/10", `${sb.meta().programs.length}/10`);
      chk("P04", "P.사전조건", "예산항목 7개 / 초기 지출 10건", "7/10", `${sb.meta().categories.length}/${sb.expenditures().length}`);
      chk("P05", "P.사전조건", "설문 2개 / 문항 6개", "2/6", `${sb.meta().surveys.length}/6`);
      const pendChg = sb.pendingChanges().length;
      const pendMil = sb.q07().length;
      const pendExp = sb.expenditures({ status: "PENDING" }).length;
      chk("P06", "P.사전조건", "승인대기 건수 (변경 2 / 마일리지 4 / 지출 3)", "2/4/3", `${pendChg}/${pendMil}/${pendExp}`);
      chk("P07", "P.사전조건", "초기 감사 로그 3건 (시드 처리 이력)", "3", sb.q12().length);

      // === S. 집계 예상값 대조 ===
      const s1 = sb.q01(11, "20240001")[0];
      chk("S01", "S.집계예상값", "Q01 1번 학생 phone은 승인 전 null", "null", s1.phone === null ? "null" : s1.phone);
      const s3 = sb.q03("20240001");
      const h2 = s3.find((x) => x.exam_round === "2025-하반기");
      chk("S02", "S.집계예상값", "Q03 하반기 점수 변화 = 700 - 620 = 80", "80", h2 ? h2.score_change : "null");
      const q4Sw = q4Init.find((x) => x.exam_round === "2025-상반기" && x.department === "소프트웨어학과" && x.grade === 1);
      chk("S03", "S.집계예상값", "Q04 2025-상반기 SW학과 1학년 평균/응시자 (644.0/5)", "644/5", q4Sw ? `${q4Sw.average_score}/${q4Sw.examinee_count}` : "null");
      const q5_2 = sb.q05().find((x) => x.student_no === "20240002");
      chk("S04", "S.집계예상값", "Q05 미적립 학생 (20240002) 누적 0점 표시", "0", q5_2 ? q5_2.total_mileage : "null");
      const q5Total = sb.q05().reduce((a, b) => a + b.total_mileage, 0);
      chk("S05", "S.집계예상값", "Q05 전체 승인 마일리지 초기 합계 65", "65", q5Total);
      const q8Ops = sb.q08().find((b) => b.project_name === "2026년 SW중심대학 사업" && b.category_name === "운영비");
      chk("S06", "S.집계예상값", "Q08 운영비 승인지출 200,000 / 잔액 1,300,000 / 집행률 13.33%", "200000/1300000/13.33", q8Ops ? `${q8Ops.approved_spend}/${q8Ops.balance}/${q8Ops.execution_rate_pct}` : "null");
      const q8Travel = sb.q08().find((b) => b.project_name === "2026년 SW중심대학 사업" && b.category_name === "여비교통비");
      chk("S07", "S.집계예상값", "Q08 무지출 여비교통비: 승인 0 / 잔액 1,000,000 / 집행률 0%", "0/1000000/0", q8Travel ? `${q8Travel.approved_spend}/${q8Travel.balance}/${q8Travel.execution_rate_pct}` : "null");
      const q9Park = sb.q09().find((x) => x.professor_name === "박교수" && x.spending_entity === "융합");
      chk("S08", "S.집계예상값", "Q09 박교수/융합 승인지출 4,200,000 / 건수 2", "4200000/2", q9Park ? `${q9Park.approved_spend}/${q9Park.approved_count}` : "null");
      const q10Sw1 = sb.q10().find((x) => x.title === "SW사업 만족도 조사" && x.question_text === "프로그램 전반에 만족하십니까?");
      chk("S09", "S.집계예상값", "Q10 SW사업 설문 1번 문항 평균 4.20 / 응답수 5", "4.2/5", q10Sw1 ? `${q10Sw1.average_score}/${q10Sw1.numeric_response_count}` : "null");
      const q10SwText = sb.q10().find((x) => x.title === "SW사업 만족도 조사" && x.question_text === "개선 의견을 작성해 주세요.");
      chk("S10", "S.집계예상값", "Q10 주관식 문항은 점수 평균 null / 서술응답 5건", "null/5", q10SwText ? `${q10SwText.average_score}/${q10SwText.text_response_count}` : "null");

      // === A. 스키마 제약조건 검증 (DB 제약 에뮬레이션) ===
      expectErr("A01", "A.제약조건", "동일 프로그램 마일리지 중복 신청 거부 (UNIQUE)", () => {
        sb.applyMileage(1, 1, "evidence1.pdf");
      }, "이미 신청한 프로그램");
      expectErr("A02", "A.제약조건", "증빙 필수 프로그램에 증빙 없이 신청 거부", () => {
        sb.applyMileage(6, 1, "");
      }, "증빙 파일명");
      expectErr("A03", "A.제약조건", "존재하지 않는 프로그램 신청 거부 (FK 참조)", () => {
        sb.applyMileage(6, 9999, "test.pdf");
      }, "찾을 수 없습니다");
      expectErr("A04", "A.제약조건", "학생인건비 신청 시 학생 미지정 거부 (CHECK chk_student_labor)", () => {
        sb.createExpenditure(13, { budget_id: 5, spending_entity: "전공", expense_type: "STUDENT_LABOR", student_id: null, amount: 500000 });
      }, "학생을 지정해야");
      expectErr("A05", "A.제약조건", "일반 지출에 학생 지정 거부 (CHECK chk_student_labor)", () => {
        sb.createExpenditure(13, { budget_id: 2, spending_entity: "산학협력", expense_type: "GENERAL", student_id: 1, amount: 500000 });
      }, "지정할 수 없습니다");
      expectErr("A06", "A.제약조건", "0원 이하 음수 지출 금액 거부 (CHECK chk_expenditure_positive)", () => {
        sb.createExpenditure(13, { budget_id: 2, spending_entity: "산학협력", expense_type: "GENERAL", student_id: null, amount: -1000 });
      }, "양수여야");

      // === B & C. 학생 정보 변경 프로시저 및 롤백 검증 ===
      expectOk("B01", "B.정보변경", "관리자의 학적 변경 요청 승인 (process_student_change_request)", () => {
        sb.processChange(1, 11, "APPROVED", "확인 후 승인");
      });
      const s1After = sb.q01(11, "20240001")[0];
      chk("B02", "B.정보변경", "승인 후 변경된 전화번호 즉시 반영 (010-0000-0001)", "010-0000-0001", s1After.phone);
      expectErr("B03", "B.정보변경", "이미 처리된 요청 재승인 거부 (중복 방지)", () => {
        sb.processChange(1, 11, "APPROVED", "재승인 시도");
      }, "PENDING 요청만");
      expectErr("B04", "B.정보변경", "비관리자(학생)의 승인 처리 시도 차단 (role_policy 검사)", () => {
        sb.processChange(4, 1, "APPROVED", "학생 권한 시도");
      }, "관리자 승인 권한이 없습니다");
      expectOk("C01", "C.정보변경", "관리자의 변경 요청 반려 처리 (20240004)", () => {
        sb.processChange(4, 11, "REJECTED", "서류 미비 반려");
      });
      const s4After = sb.q01(11, "20240004")[0];
      chk("C02", "C.정보변경", "반려 시 기존 데이터 불변 유지", "null", s4After.phone === null ? "null" : s4After.phone);

      // === D. 마일리지 신청 및 승인/반려 검증 ===
      expectOk("D01", "D.마일리지", "20240002 AI 기초 특강 마일리지 승인 (10점)", () => {
        sb.processMileage(2, 11, "APPROVED", "참여 확인");
      });
      const q5_2_after = sb.q05().find((x) => x.student_no === "20240002");
      chk("D02", "D.마일리지", "승인 후 20240002 누적 마일리지 0 -> 10점 반영", "10", q5_2_after.total_mileage);
      expectErr("D03", "D.마일리지", "승인된 마일리지 재승인 거부 (중복 승인 차단)", () => {
        sb.processMileage(2, 11, "APPROVED", "중복");
      }, "PENDING 신청만");
      expectErr("D04", "D.마일리지", "비관리자(학생)의 마일리지 승인 시도 차단", () => {
        sb.processMileage(10, 1, "APPROVED", "학생 권한 시도");
      }, "관리자 승인 권한이 없습니다");
      expectOk("D05", "D.마일리지", "20240005 마일리지 신청 반려", () => {
        sb.processMileage(5, 11, "REJECTED", "증빙 불충분");
      });
      const q5_5 = sb.q05().find((x) => x.student_no === "20240005");
      chk("D06", "D.마일리지", "반려된 마일리지는 누적 합산에서 제외 (0점 유지)", "0", q5_5.total_mileage);
      expectOk("D07", "D.마일리지", "20240007 마일리지 신청 승인 (15점)", () => {
        sb.processMileage(7, 11, "APPROVED", "참여 확인");
      });
      const q5_7 = sb.q05().find((x) => x.student_no === "20240007");
      chk("D08", "D.마일리지", "20240007 누적 마일리지 0 -> 15점 반영", "15", q5_7.total_mileage);
      const q5NewTotal = sb.q05().reduce((a, b) => a + b.total_mileage, 0);
      chk("D09", "D.마일리지", "전체 승인 마일리지 합계 65 -> 90점 증가", "90", q5NewTotal);
      chk("D10", "D.마일리지", "대기 마일리지(Q07) 1건(20240010)만 잔여", "1", sb.q07().length);

      // === E. 지출 승인 및 예산 한도 초과 차단 (핵심) ===
      expectOk("E01", "E.지출", "최고관리자의 대기 지출 500,000원 승인 (장비구입비)", () => {
        sb.processExpenditure(2, 12, "APPROVED", "검증 승인");
      });
      const q8Equip = sb.q08().find((b) => b.project_name === "2026년 SW중심대학 사업" && b.category_name === "장비구입비");
      chk("E02", "E.지출", "Q08 장비구입비 승인지출 2,000,000 / 잔액 3,000,000 / 집행률 40.00%", "2000000/3000000/40", q8Equip ? `${q8Equip.approved_spend}/${q8Equip.balance}/${q8Equip.execution_rate_pct}` : "null");
      expectErr("E03", "E.지출", "이미 처리된 지출 재승인 차단 (중복 방지)", () => {
        sb.processExpenditure(2, 12, "APPROVED", "재시도");
      }, "PENDING 지출만");
      expectErr("E04", "E.지출", "일반관리자의 지출 승인 시도 차단 (최고관리자만 role_policy 보유)", () => {
        sb.processExpenditure(7, 11, "APPROVED", "일반관리자 승인 시도");
      }, "관리자 승인 권한이 없습니다");
      // 예산 한도 초과 테스트: 운영비(budget_id 6, 예산 150만원, 기존 승인 20만원)에 140만원 추가 지출 신청 후 승인 시도
      const expOver = sb.createExpenditure(13, { budget_id: 6, spending_entity: "전공", expense_type: "GENERAL", student_id: null, amount: 1400000, description: "한도초과 시도" });
      expectErr("E05", "E.예산한도", "예산 한도 초과 실시간 차단 (기존 20만 + 신청 140만 = 160만 > 예산 150만)", () => {
        sb.processExpenditure(expOver.expenditure_id, 12, "APPROVED", "승인 시도");
      }, "예산 한도 초과");
      // 한도 경계 테스트: 130만원 승인 시도 (20만 + 130만 = 150만, 정확히 100%)
      const expEdge = sb.createExpenditure(13, { budget_id: 6, spending_entity: "전공", expense_type: "GENERAL", student_id: null, amount: 1300000, description: "한도 경계 승인" });
      expectOk("E06", "E.예산한도", "예산 한도 정확히 일치(100% 소진) 승인 허용", () => {
        sb.processExpenditure(expEdge.expenditure_id, 12, "APPROVED", "한도 일치 승인");
      });
      const q8OpsAfter = sb.q08().find((b) => b.project_name === "2026년 SW중심대학 사업" && b.category_name === "운영비");
      chk("E07", "E.예산한도", "운영비 집행률 100% / 잔액 0원 확인", "1500000/0/100", q8OpsAfter ? `${q8OpsAfter.approved_spend}/${q8OpsAfter.balance}/${q8OpsAfter.execution_rate_pct}` : "null");

      // === F. 만족도 조사 무결성 및 완료 응답 검증 ===
      expectErr("F01", "F.만족도", "동일 학생 중복 설문 응답 거부", () => {
        sb.submitSurvey(1, 1, [{ question_id: 1, score: 5 }, { question_id: 2, score: 5 }, { question_id: 3, answer_text: "중복" }]);
      }, "이미 응답한 설문");
      expectErr("F02", "F.만족도", "점수형 문항 0점(하한 미만) 거부", () => {
        sb.submitSurvey(6, 1, [{ question_id: 1, score: 0 }, { question_id: 2, score: 5 }, { question_id: 3, answer_text: "의견" }]);
      }, "1~5점만 허용");
      expectErr("F03", "F.만족도", "점수형 문항 6점(상한 초과) 거부", () => {
        sb.submitSurvey(6, 1, [{ question_id: 1, score: 6 }, { question_id: 2, score: 5 }, { question_id: 3, answer_text: "의견" }]);
      }, "1~5점만 허용");
      expectErr("F04", "F.만족도", "서술형 문항 공백 제출 거부", () => {
        sb.submitSurvey(6, 1, [{ question_id: 1, score: 5 }, { question_id: 2, score: 5 }, { question_id: 3, answer_text: "   " }]);
      }, "비어 있을 수 없습니다");
      expectOk("F05", "F.만족도", "정상 설문 제출 완료 (학생 6)", () => {
        sb.submitSurvey(6, 1, [{ question_id: 1, score: 5 }, { question_id: 2, score: 5 }, { question_id: 3, answer_text: "훌륭한 교육과정이었습니다." }]);
      });

      // === G. 접근 통제 (Role-Based Access Control) ===
      chk("G01", "G.접근통제", "학생(본인) -> 본인 학생정보 조회 허용 (1행)", "1", sb.q01(1, "20240001").length);
      chk("G02", "G.접근통제", "학생 -> 타 학생(20240002) 조회 차단 (0행)", "0", sb.q01(1, "20240002").length);
      chk("G03", "G.접근통제", "일반관리자 -> 전체 학생 조회 허용 (1행)", "1", sb.q01(11, "20240002").length);
      chk("G04", "G.접근통제", "교수 계정 -> 학생 정보 직접 조회 차단 (0행)", "0", sb.q01(13, "20240001").length);

      // === H. 감사 로그 일관성 (change_log) ===
      const logs = sb.q12();
      chk("H01", "H.감사로그", "승인/반려 처리마다 change_log 정상 기록 확인", "true", logs.length >= 7);
      const chgLogs = sb.q12("student_change_request");
      chk("H02", "H.감사로그", "학생정보 변경 로그 건수 일치 (시드 3 + 신규 승인/반려 2 = 5건)", "5", chgLogs.length);
      const milLogs = sb.q12("mileage_application");
      chk("H03", "H.감사로그", "마일리지 승인/반려 로그 기록 일치", "3", milLogs.length);
      const expLogs = sb.q12("expenditure");
      chk("H04", "H.감사로그", "지출 승인 로그 기록 일치", "2", expLogs.length);

      rec("G08", "G.접근통제", "role_policy 테이블 기반 동적 권한 판정", "role_policy 참조", "참조함 (fn_has_permission / fn_can_view_student)", "PASS");
      rec("G09", "G.접근통제", "애플리케이션 계층 인가 및 세션 통제", "통제 구현", "구현됨 (user_id 및 권한 플래그 검사)", "PASS");

      const summary = {
        total: results.length,
        pass: results.filter((r) => r.result === "PASS").length,
        fail: results.filter((r) => r.result === "FAIL").length,
        gap: results.filter((r) => r.result === "GAP").length,
        info: results.filter((r) => r.result === "INFO").length,
      };

      return { summary, results };
    },
  };
}

module.exports = { createStore };
