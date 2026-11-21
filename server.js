"use strict";

const http = require("http");
const fs = require("fs");
const path = require("path");
const mysql = require("mysql2/promise");
const { createStore } = require("./store");
const { createMysqlStore } = require("./mysql_store");

let store = createStore();
let dbMode = "IN_MEMORY";

async function initDb() {
  try {
    const pool = mysql.createPool({
      host: "127.0.0.1",
      port: 3307, // Docker 컨테이너 pbl-mysql 바인딩 포트
      user: "root",
      password: "pblpass",
      database: "pbl_db",
      waitForConnections: true,
      connectionLimit: 10,
      charset: "utf8mb4",
      timezone: "+09:00", // 한국 표준시 KST 적용
      dateStrings: true   // DATETIME을 UTC 변환 없이 YYYY-MM-DD HH:mm:ss 원본 문자열로 반환
    });
    // DB 세션 및 글로벌 타임존을 한국 표준시(+09:00)로 강제 동기화
    await pool.query("SET GLOBAL time_zone = '+09:00'");
    await pool.query("SET time_zone = '+09:00'");
    const [rows] = await pool.query("SELECT 1 AS ok");
    if (rows && rows[0] && rows[0].ok === 1) {
      store = createMysqlStore(pool);
      dbMode = "REAL_MYSQL";
      console.log(">> [성공] 실제 컴퓨터의 MySQL DB (Docker pbl-mysql: 127.0.0.1:3307) 연동 완료!");
    }
  } catch (err) {
    console.warn(">> [안내] 실제 MySQL 연결 불가 (" + err.message + ") -> 인메모리 스토어로 동작합니다.");
  }
}
initDb();

const PORT = Number(process.env.PORT) || 3000;
const PUBLIC = path.join(__dirname, "public");

const mime = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

function send(res, code, body, type = "application/json; charset=utf-8") {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" });
  if (Buffer.isBuffer(body) || typeof body === "string") res.end(body);
  else res.end(JSON.stringify(body));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (!raw) return resolve({});
      try { resolve(JSON.parse(raw)); } catch (e) { reject(e); }
    });
    req.on("error", reject);
  });
}

function query(url) {
  const q = {};
  for (const [k, v] of url.searchParams) q[k] = v;
  return q;
}

function uid(q) {
  const id = Number(q.user_id);
  if (!id) {
    const e = new Error("user_id가 필요합니다.");
    e.status = 401;
    throw e;
  }
  return id;
}

async function api(req, res, url) {
  const q = query(url);
  const p = url.pathname;
  try {
    if (req.method === "POST" && p === "/api/login") {
      const body = await parseBody(req);
      const sess = await store.session(String(body.login_id || "").trim());
      sess.db_mode = dbMode;
      return send(res, 200, sess);
    }
    if (req.method === "POST" && p === "/api/reset") {
      await store.reset();
      return send(res, 200, { ok: true, db_mode: dbMode });
    }
    if (req.method === "GET" && p === "/api/tests") {
      const t = await store.runTests();
      return send(res, 200, t);
    }
    if (req.method === "GET" && p === "/api/meta") {
      const m = await store.meta();
      m.db_mode = dbMode;
      return send(res, 200, m);
    }
    if (req.method === "GET" && p === "/api/q01") return send(res, 200, await store.q01(uid(q), q.student_no));
    if (req.method === "GET" && p === "/api/q02") return send(res, 200, await store.q02(q.student_no));
    if (req.method === "GET" && p === "/api/pending-changes") return send(res, 200, await store.pendingChanges());
    if (req.method === "GET" && p === "/api/q03") return send(res, 200, await store.q03(q.student_no));
    if (req.method === "GET" && p === "/api/q04") return send(res, 200, await store.q04());
    if (req.method === "GET" && p === "/api/q05") return send(res, 200, await store.q05());
    if (req.method === "GET" && p === "/api/q06") {
      return send(res, 200, await store.q06(Number(q.program_id), q.date_from, q.date_to));
    }
    if (req.method === "GET" && p === "/api/q07") return send(res, 200, await store.q07());
    if (req.method === "GET" && p === "/api/q08") return send(res, 200, await store.q08());
    if (req.method === "GET" && p === "/api/q09") return send(res, 200, await store.q09());
    if (req.method === "GET" && p === "/api/q10") return send(res, 200, await store.q10());
    if (req.method === "GET" && p === "/api/q11") return send(res, 200, await store.q11());
    if (req.method === "GET" && p === "/api/q12") return send(res, 200, await store.q12(q.target_type || null, q.target_id || null));
    if (req.method === "GET" && p === "/api/expenditures") {
      return send(res, 200, await store.expenditures({
        status: q.status || null,
        professor_id: q.professor_id ? Number(q.professor_id) : null,
      }));
    }
    if (req.method === "GET" && p === "/api/my-mileage") return send(res, 200, await store.myMileage(uid(q)));

    if (req.method === "POST" && p === "/api/change-request") {
      const b = await parseBody(req);
      return send(res, 200, await store.createChangeRequest(uid(q), b.field, b.new_value));
    }
    if (req.method === "POST" && p === "/api/process-change") {
      const b = await parseBody(req);
      return send(res, 200, await store.processChange(Number(b.request_id), uid(q), b.decision, b.comment));
    }
    if (req.method === "POST" && p === "/api/mileage") {
      const b = await parseBody(req);
      return send(res, 200, await store.applyMileage(uid(q), Number(b.program_id), b.evidence_file_name));
    }
    if (req.method === "POST" && p === "/api/process-mileage") {
      const b = await parseBody(req);
      return send(res, 200, await store.processMileage(Number(b.application_id), uid(q), b.decision, b.comment));
    }
    if (req.method === "POST" && p === "/api/expenditure") {
      const b = await parseBody(req);
      return send(res, 200, await store.createExpenditure(uid(q), b));
    }
    if (req.method === "POST" && p === "/api/process-expenditure") {
      const b = await parseBody(req);
      return send(res, 200, await store.processExpenditure(Number(b.expenditure_id), uid(q), b.decision, b.comment));
    }
    if (req.method === "POST" && p === "/api/survey") {
      const b = await parseBody(req);
      return send(res, 200, await store.submitSurvey(uid(q), Number(b.survey_id), b.answers));
    }
    send(res, 404, { error: "API not found" });
  } catch (e) {
    send(res, e.status || 400, { error: e.message || String(e) });
  }
}

function serveStatic(req, res, url) {
  let rel = decodeURIComponent(url.pathname);
  if (rel === "/") rel = "/index.html";
  const file = path.normalize(path.join(PUBLIC, rel));
  if (!file.startsWith(PUBLIC)) return send(res, 403, "Forbidden", "text/plain");
  fs.readFile(file, (err, data) => {
    if (err) return send(res, 404, "Not found", "text/plain");
    send(res, 200, data, mime[path.extname(file)] || "application/octet-stream");
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname.startsWith("/api/")) return api(req, res, url);
  serveStatic(req, res, url);
});

server.listen(PORT, () => {
  console.log(`PBL Mission 2 사이트: http://localhost:${PORT}`);
});
