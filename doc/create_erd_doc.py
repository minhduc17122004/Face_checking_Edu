"""
Generate ERD Database Specification as a Word document (.docx)
Hệ thống Điểm danh Khuôn mặt - Face Attendance System
"""
from docx import Document
from docx.shared import Pt, RGBColor, Cm, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = Document()

# ─── Page setup (A4 landscape) ───────────────────────────────
section = doc.sections[0]
section.page_width    = Cm(29.7)
section.page_height   = Cm(21.0)
section.left_margin   = Cm(1.8)
section.right_margin  = Cm(1.8)
section.top_margin    = Cm(1.5)
section.bottom_margin = Cm(1.5)

# ─── Helper: set cell background colour ──────────────────────
def set_cell_bg(cell, hex_color):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_color)
    tcPr.append(shd)

# ─── Helper: colour a sub-string within cell text ────────────
def colour_keyword(cell, keyword, hex_color):
    """Find keyword in cell text and colour it."""
    for para in cell.paragraphs:
        for run in para.runs:
            if run.text == keyword:
                run.font.color.rgb = RGBColor(*bytes.fromhex(hex_color))
                run.bold = True
                return

# ─── Helper: add a table ─────────────────────────────────────
def make_table(doc, headers, rows):
    tbl = doc.add_table(rows=1 + len(rows), cols=len(headers))
    tbl.style = 'Table Grid'
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    # Header
    hdr_cells = tbl.rows[0].cells
    for i, h in enumerate(headers):
        set_cell_bg(hdr_cells[i], '2C3E50')
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(h)
        run.bold = True
        run.font.size = Pt(9)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        hdr_cells[i].vertical_alignment = WD_ALIGN_VERTICAL.CENTER
    # Data
    for r_idx, row_data in enumerate(rows):
        row_cells = tbl.rows[r_idx + 1].cells
        bg = 'F2F2F2' if r_idx % 2 == 0 else 'FFFFFF'
        for c_idx, cell_text in enumerate(row_data):
            set_cell_bg(row_cells[c_idx], bg)
            p = row_cells[c_idx].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            run = p.add_run(cell_text)
            run.font.size = Pt(9)
            row_cells[c_idx].vertical_alignment = WD_ALIGN_VERTICAL.CENTER
    doc.add_paragraph('')
    return tbl

# ─── Helper: section heading ───────────────────────────────────
def add_heading(doc, text, level=1):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run(text)
    run.bold = True
    if level == 1:
        run.font.size = Pt(13)
        run.font.color.rgb = RGBColor(0x1F, 0x5C, 0x8B)
    else:
        run.font.size = Pt(10)
        run.font.color.rgb = RGBColor(0x2E, 0x7D, 0x32)
    return p

# ─── Helper: body paragraph ──────────────────────────────────
def add_body(doc, text):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.size = Pt(10)
    run.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
    return p

# ═══════════════════════════════════════════════════════════════
#  TITLE
# ═══════════════════════════════════════════════════════════════
title_p = doc.add_paragraph()
title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
title_run = title_p.add_run('ĐẶC TẢ CƠ SỞ DỮ LIỆU')
title_run.bold = True
title_run.font.size = Pt(24)
title_run.font.color.rgb = RGBColor(0x1F, 0x5C, 0x8B)

sub_p = doc.add_paragraph()
sub_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
sub_run = sub_p.add_run('Hệ thống Điểm danh Khuôn mặt | Face Attendance System')
sub_run.font.size = Pt(14)
sub_run.font.color.rgb = RGBColor(0x44, 0x44, 0x44)

meta_p = doc.add_paragraph()
meta_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
meta_run = meta_p.add_run('Ngày: 28/03/2026  |  Tổng số bảng: 18  |  ERD v1.0')
meta_run.font.size = Pt(10)
meta_run.font.color.rgb = RGBColor(0x88, 0x88, 0x88)

doc.add_paragraph('')

# ─── Legend ───────────────────────────────────────────────────
add_heading(doc, 'CHÚ THÍCH KHÓA', 1)
leg_tbl = doc.add_table(rows=2, cols=4)
leg_tbl.alignment = WD_TABLE_ALIGNMENT.LEFT
for i, (sym, lbl, col) in enumerate([
    ('PK', 'Khóa chính (Primary Key)',          '1F5C8B'),
    ('FK', 'Khóa ngoại (Foreign Key)',            '2E7D32'),
    ('UK', 'Khóa duy nhất (Unique Key)',         'F57C00'),
    ('—',  'Trường thông thường',                 '888888'),
]):
    c = leg_tbl.rows[0].cells[i]
    set_cell_bg(c, col)
    p = c.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r1 = p.add_run(sym)
    r1.bold = True
    r1.font.size = Pt(10)
    r1.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    c2 = leg_tbl.rows[1].cells[i]
    p2 = c2.paragraphs[0]
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r2 = p2.add_run(lbl)
    r2.font.size = Pt(8)
    r2.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
doc.add_paragraph('')

# ─── Overview ─────────────────────────────────────────────────
add_heading(doc, 'TỔNG QUAN HỆ THỐNG', 1)
overview_tbl = doc.add_table(rows=1, cols=4)
overview_tbl.style = 'Table Grid'
overview_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
overview_hdrs = overview_tbl.rows[0].cells
for i, h in enumerate(['Nhóm', 'Số bảng', 'Tên bảng', 'Mô tả']):
    set_cell_bg(overview_hdrs[i], '34495E')
    p = overview_hdrs[i].paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(h)
    run.bold = True
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
overview_data = [
    ('Xác thực & Người dùng', '4', 'users, teachers, students, refresh_tokens',   'Tài khoản, phân quyền, JWT token'),
    ('Học thuật',             '6', 'departments, student_groups, courses,\ncourse_enrollments, time_slots, schedules', 'Khoa, lớp hành chính, lớp HP, đăng ký, tiết học, lịch'),
    ('Phiên & Điểm danh',     '4', 'sessions, attendances, attendance_configs,\nattendance_audit_logs', 'Phiên học, bản ghi điểm danh, cấu hình, audit log'),
    ('Khuôn mặt & Thiết bị',  '4', 'face_embeddings, rooms, devices,\ndevice_requests', 'Vector khuôn mặt, phòng, thiết bị, yêu cầu cấp quyền'),
]
for r_idx, row in enumerate(overview_data):
    cells = overview_tbl.add_row().cells
    bg = 'EBF5FB' if r_idx % 2 == 0 else 'FFFFFF'
    for c_idx, val in enumerate(row):
        set_cell_bg(cells[c_idx], bg)
        p = cells[c_idx].paragraphs[0]
        run = p.add_run(val)
        run.font.size = Pt(9)
        cells[c_idx].vertical_alignment = WD_ALIGN_VERTICAL.TOP
doc.add_paragraph('')

# ═══════════════════════════════════════════════════════════════
#  TABLE DEFINITIONS
# ═══════════════════════════════════════════════════════════════
HEADERS = ['Tên cột', 'Kiểu dữ liệu', 'Khóa', 'Khác', 'Mô tả']

tables_def = [
    # ── USERS ──────────────────────────────────────────────────
    ('BẢNG 1: USERS', 'Bảng trung tâm — lưu tài khoản cho tất cả người dùng (admin / teacher / student). Tên, avatar được lưu tại đây — single source of truth.',
     [
         ('id',             'UUID',         'PK', 'NOT NULL, DEFAULT uuid_generate_v4()',                                                 'Khóa chính định danh người dùng'),
         ('email',          'VARCHAR(255)',  'UK', 'NOT NULL',                                                                          'Email đăng nhập, duy nhất không trùng'),
         ('password_hash',  'VARCHAR(255)',  '—',  'NOT NULL',                                                                          'Mật khẩu đã băm (bcrypt/argon2)'),
         ('full_name',      'VARCHAR(255)',  '—',  'NOT NULL',                                                                          'Họ và tên đầy đủ'),
         ('role',           'VARCHAR(20)',   '—',  "NOT NULL, DEFAULT 'student'\nCHECK(role IN ('admin','teacher','student'))",            'Vai trò người dùng'),
         ('avatar_url',     'VARCHAR(500)',  '—',  'NULLABLE',                                                                          'URL ảnh đại diện'),
         ('created_at',     'TIMESTAMPTZ',   '—',  'NOT NULL, DEFAULT NOW()',                                                            'Thời gian tạo tài khoản'),
         ('updated_at',     'TIMESTAMPTZ',   '—',  'NOT NULL, DEFAULT NOW()',                                                            'Thời gian cập nhật gần nhất'),
         ('deleted_at',     'TIMESTAMPTZ',   '—',  'NULLABLE, INDEX',                                                                    'Soft delete — NULL = đang hoạt động'),
     ]),
    # ── REFRESH_TOKENS ────────────────────────────────────────
    ('BẢNG 2: REFRESH_TOKENS', 'Lưu trữ JWT refresh token cho cơ chế đăng nhập. Hỗ trợ revoke token khi đăng xuất hoặc admin thu hồi.',
     [
         ('id',           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',      'Khóa chính'),
         ('user_id',      'UUID',        'FK',  'NOT NULL, → users.id ON DELETE CASCADE',    'Người dùng sở hữu token'),
         ('token_jti',    'VARCHAR(64)', 'UK',  'NOT NULL',                                   'JWT Token ID (jti claim), dùng revoke'),
         ('device_id',    'VARCHAR(255)','—',   'NULLABLE',                                   'ID thiết bị đã đăng nhập'),
         ('device_info',  'JSONB',       '—',   'NULLABLE',                                   'Metadata thiết bị: browser, OS, IP...'),
         ('expires_at',   'TIMESTAMPTZ', '—',   'NOT NULL',                                   'Thời điểm token hết hạn'),
         ('revoked',      'BOOLEAN',     '—',   'NOT NULL, DEFAULT FALSE',                   'Cờ thu hồi — TRUE = đã bị thu hồi'),
         ('created_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                   'Thời gian tạo token'),
     ]),
    # ── TEACHERS ───────────────────────────────────────────────
    ('BẢNG 3: TEACHERS', 'Hồ sơ giáo viên — quan hệ 1:1 nghiêm ngặt với User (role=\'teacher\'). Mã giáo viên, SĐT, khoa được lưu tại đây.',
     [
         ('id',            'SERIAL / INT', 'PK',   'NOT NULL, AUTO INCREMENT',                          'Khóa chính dạng số nguyên (tương thích Flutter)'),
         ('user_id',       'UUID',          'FK, UK','NOT NULL, → users.id ON DELETE CASCADE',          'Liên kết 1:1 với bảng users'),
         ('teacher_id',    'VARCHAR(50)',  'UK',    'NULLABLE',                                          'Mã giáo viên, duy nhất'),
         ('phone',         'VARCHAR(20)',  '—',     'NULLABLE',                                          'Số điện thoại liên hệ'),
         ('department_id', 'UUID',          'FK',    'NULLABLE, → departments.id ON DELETE SET NULL',  'Khoa mà giáo viên thuộc về'),
         ('created_at',    'TIMESTAMPTZ',  '—',      'NOT NULL, DEFAULT NOW()',                          'Thời gian tạo hồ sơ'),
         ('updated_at',    'TIMESTAMPTZ',  '—',      'NOT NULL, DEFAULT NOW()',                          'Thời gian cập nhật gần nhất'),
         ('deleted_at',    'TIMESTAMPTZ',  '—',      'NULLABLE, INDEX',                                   'Soft delete'),
     ]),
    # ── STUDENTS ───────────────────────────────────────────────
    ('BẢNG 4: STUDENTS', 'Hồ sơ sinh viên — quan hệ 1:1 nghiêm ngặt với User (role=\'student\'). Sử dụng khóa chính INT (không phải UUID) để tương thích Flutter.',
     [
         ('id',              'SERIAL / INT', 'PK',    'NOT NULL, AUTO INCREMENT',                              'Khóa chính dạng số nguyên (tương thích Flutter)'),
         ('user_id',         'UUID',          'FK, UK', 'NOT NULL, → users.id ON DELETE CASCADE',              'Liên kết 1:1 với bảng users'),
         ('student_code',    'VARCHAR(50)',   'UK',     'NULLABLE',                                              'Mã sinh viên (MSSV), duy nhất không trùng'),
         ('pin',             'VARCHAR(10)',   '—',      'NULLABLE',                                              'Mã PIN xác thực offline (mã hóa)'),
         ('student_group_id','UUID',          'FK',     'NULLABLE, → student_groups.id ON DELETE SET NULL',   'Lớp chủ quản mà sinh viên thuộc về'),
         ('created_at',      'TIMESTAMPTZ',   '—',      'NOT NULL, DEFAULT NOW()',                              'Thời gian tạo hồ sơ'),
         ('updated_at',      'TIMESTAMPTZ',   '—',      'NOT NULL, DEFAULT NOW()',                              'Thời gian cập nhật gần nhất'),
         ('deleted_at',      'TIMESTAMPTZ',   '—',      'NULLABLE, INDEX',                                       'Soft delete'),
         ('created_by',      'UUID',          '—',      'NULLABLE',                                              'Người tạo hồ sơ sinh viên'),
         ('updated_by',      'UUID',          '—',      'NULLABLE',                                              'Người cập nhật hồ sơ sinh viên'),
     ]),
    # ── DEPARTMENTS ────────────────────────────────────────────
    ('BẢNG 5: DEPARTMENTS', 'Khoa / Bộ môn — đơn vị tổ chức học thuật. Giáo viên, sinh viên, khóa học có thể gắn với một khoa.',
     [
         ('id',         'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',   'Khóa chính'),
         ('code',       'VARCHAR(50)', 'UK',  'NOT NULL',                               'Mã khoa, duy nhất (ví dụ: "CNTT", "Toán")'),
         ('name',       'VARCHAR(255)','—',   'NOT NULL',                               'Tên đầy đủ của khoa'),
         ('created_at', 'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',               'Thời gian tạo khoa'),
         ('updated_at', 'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',               'Thời gian cập nhật gần nhất'),
         ('deleted_at', 'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                        'Soft delete'),
         ('created_by', 'UUID',        '—',   'NULLABLE',                               'Người tạo khoa'),
         ('updated_by', 'UUID',        '—',   'NULLABLE',                               'Người cập nhật khoa'),
     ]),
    # ── STUDENT_GROUPS ─────────────────────────────────────────
    ('BẢNG 6: STUDENT_GROUPS', 'Lớp chủ quản — nhóm hành chính sinh viên (ví dụ: "48K21.1", "CNTT-K25"). Khác với Course (lớp học phần), bảng này dùng cho hành chính.',
     [
         ('id',           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',           'Khóa chính'),
         ('code',         'VARCHAR(50)', 'UK',  'NOT NULL',                                       'Mã lớp, duy nhất (ví dụ: "48K21.1")'),
         ('name',         'VARCHAR(255)','—',   'NULLABLE',                                       'Tên lớp (tên thường gọi)'),
         ('department_id','UUID',        'FK',  'NULLABLE, → departments.id ON DELETE SET NULL', 'Khoa quản lý lớp này'),
         ('advisor_id',   'UUID',        'FK',  'NULLABLE, → users.id ON DELETE SET NULL',      'Giảng viên chủ nhiệm (GV cố vấn)'),
         ('created_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                       'Thời gian tạo lớp'),
         ('updated_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                       'Thời gian cập nhật gần nhất'),
         ('deleted_at',   'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                                'Soft delete'),
         ('created_by',   'UUID',        '—',   'NULLABLE',                                       'Người tạo lớp'),
         ('updated_by',   'UUID',        '—',   'NULLABLE',                                       'Người cập nhật lớp'),
     ]),
    # ── COURSES ────────────────────────────────────────────────
    ('BẢNG 7: COURSES', 'Lớp học phần — đại diện cho một môn học cụ thể trong một học kỳ. Mỗi course được giảng dạy bởi một giáo viên và có nhiều sinh viên đăng ký.',
     [
         ('id',                           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',               'Khóa chính'),
         ('course_name',                  'VARCHAR(255)', '—',   'NOT NULL',                                           'Tên lớp học phần'),
         ('course_code',                  'VARCHAR(50)',  'UK',  'NULLABLE',                                           'Mã môn học (ví dụ: "CS101")'),
         ('teacher_id',                  'INT',          'FK',  'NULLABLE, → teachers.id ON DELETE SET NULL',      'Giáo viên giảng dạy'),
         ('department_id',                'UUID',         'FK',  'NULLABLE, → departments.id ON DELETE SET NULL',   'Khoa sở hữu lớp'),
         ('room_id',                     'UUID',         'FK',  'NULLABLE, → rooms.id ON DELETE SET NULL',        'Phòng học chính của lớp'),
         ('attendance_mode',              'VARCHAR(20)',  '—',   "NOT NULL, DEFAULT 'preset'\nCHECK(attendance_mode IN ('preset','flexible'))", 'Chế độ điểm danh'),
         ('custom_window_start_minutes', 'INT',          '—',   'NOT NULL, DEFAULT 0',                               'Phút cho phép checkin trước giờ bắt đầu'),
         ('custom_window_end_minutes',   'INT',          '—',   'NOT NULL, DEFAULT 30',                              'Phút cho phép checkin sau giờ bắt đầu'),
         ('course_start_date',            'DATE',         '—',   'NULLABLE',                                           'Ngày bắt đầu hiệu lực khóa học'),
         ('course_end_date',              'DATE',         '—',   'NULLABLE',                                           'Ngày kết thúc hiệu lực khóa học'),
         ('created_at',                   'TIMESTAMPTZ',  '—',   'NOT NULL, DEFAULT NOW()',                           'Thời gian tạo lớp học phần'),
         ('updated_at',                   'TIMESTAMPTZ',  '—',   'NOT NULL, DEFAULT NOW()',                           'Thời gian cập nhật gần nhất'),
         ('deleted_at',                   'TIMESTAMPTZ',  '—',   'NULLABLE, INDEX',                                    'Soft delete'),
         ('created_by',                   'UUID',         '—',   'NULLABLE',                                           'Người tạo lớp'),
         ('updated_by',                   'UUID',         '—',   'NULLABLE',                                           'Người cập nhật lớp'),
     ]),
    # ── COURSE_ENROLLMENTS ──────────────────────────────────────
    ('BẢNG 8: COURSE_ENROLLMENTS', 'Bảng trung gian — quan hệ N:N giữa COURSES và STUDENTS. Mỗi bản ghi = một sinh viên đăng ký một lớp học phần.',
     [
         ('id',         'UUID', 'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',     'Khóa chính'),
         ('course_id',  'UUID', 'FK',  'NOT NULL, → courses.id ON DELETE CASCADE', 'Lớp học phần được đăng ký'),
         ('student_id', 'INT',  'FK',  'NOT NULL, → students.id ON DELETE CASCADE','Sinh viên đăng ký'),
         ('enrolled_at','TIMESTAMPTZ', '—', 'NOT NULL, DEFAULT NOW()',              'Thời gian đăng ký'),
     ]),
    # ── TIME_SLOTS ──────────────────────────────────────────────
    ('BẢNG 9: TIME_SLOTS', 'Định nghĩa các tiết học trong ngày — mang tính toàn cục, dùng chung cho mọi khóa học. Ví dụ: Tiết 1 (07:00–08:00), Tiết 2 (08:00–09:00).',
     [
         ('id',           'SERIAL / INT', 'PK',  'NOT NULL, AUTO INCREMENT',         'Khóa chính dạng số nguyên'),
         ('period_number','INT',          'UK',  'NOT NULL',                          'Số thứ tự tiết trong ngày (1, 2, 3...)'),
         ('start_time',   'TIME',         '—',   'NOT NULL',                          'Giờ bắt đầu tiết học'),
         ('end_time',     'TIME',         '—',   'NOT NULL\nCHECK(end_time > start_time)', 'Giờ kết thúc tiết học'),
         ('created_at',   'TIMESTAMPTZ',  '—',   'NOT NULL, DEFAULT NOW()',           'Thời gian tạo tiết học'),
     ]),
    # ── SCHEDULES ───────────────────────────────────────────────
    ('BẢNG 10: SCHEDULES', 'Lịch học tuần — liên kết một COURSES với một ngày trong tuần và một TIME_SLOT. Ví dụ: Lớp CS101 học Thứ 2, Tiết 3.',
     [
         ('id',           'UUID',       'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',            'Khóa chính'),
         ('course_id',    'UUID',       'FK',  'NOT NULL, → courses.id ON DELETE CASCADE',       'Lớp học phần được xếp lịch'),
         ('day_of_week',  'INT',        '—',   'NOT NULL, CHECK(day_of_week BETWEEN 1 AND 7)',   'Thứ trong tuần (1=Thứ 2, 7=Chủ nhật)'),
         ('time_slot_id', 'INT',        'FK',  'NOT NULL, → time_slots.id ON DELETE RESTRICT', 'Tiết học trong ngày'),
         ('created_at',   'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                       'Thời gian tạo lịch'),
         ('updated_at',   'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                       'Thời gian cập nhật gần nhất'),
         ('deleted_at',   'TIMESTAMPTZ','—',   'NULLABLE, INDEX',                                'Soft delete'),
         ('created_by',   'UUID',       '—',   'NULLABLE',                                       'Người tạo lịch'),
         ('updated_by',   'UUID',       '—',   'NULLABLE',                                       'Người cập nhật lịch'),
     ]),
    # ── SESSIONS ────────────────────────────────────────────────
    ('BẢNG 11: SESSIONS', 'Phiên điểm danh — một instance cụ thể của một COURSES vào một ngày cụ thể. Đại diện cho "buổi học thứ N" của một lớp. Trạng thái: scheduled → active → closed.',
     [
         ('id',                    'UUID',       'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',             'Khóa chính'),
         ('course_id',             'UUID',       'FK',  'NOT NULL, → courses.id ON DELETE CASCADE',       'Lớp học phần mà phiên này thuộc về'),
         ('schedule_id',           'UUID',       'FK',  'NULLABLE, → schedules.id ON DELETE SET NULL',  'Lịch học gốc sinh ra phiên này'),
         ('session_date',          'DATE',       '—',   'NOT NULL',                                        'Ngày diễn ra phiên điểm danh'),
         ('start_time',            'TIMESTAMPTZ','—',   'NOT NULL',                                        'Thời điểm bắt đầu phiên'),
         ('end_time',              'TIMESTAMPTZ','—',   'NULLABLE',                                        'Thời điểm kết thúc phiên'),
         ('checkin_window_start',  'TIMESTAMPTZ','—',   'NULLABLE',                                        'Bắt đầu cho phép điểm danh'),
         ('checkin_window_end',    'TIMESTAMPTZ','—',   'NULLABLE',                                        'Kết thúc cho phép điểm danh'),
         ('status',                'VARCHAR(20)', '—',  "NOT NULL, DEFAULT 'scheduled'\nCHECK(status IN ('scheduled','active','closed'))", 'Trạng thái phiên'),
         ('created_at',            'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                        'Thời gian tạo phiên'),
         ('updated_at',            'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                        'Thời gian cập nhật gần nhất'),
         ('deleted_at',            'TIMESTAMPTZ','—',   'NULLABLE, INDEX',                                'Soft delete'),
     ]),
    # ── ATTENDANCES ─────────────────────────────────────────────
    ('BẢNG 12: ATTENDANCES', 'Bản ghi điểm danh — mỗi bản ghi = một sinh viên checkin trong một phiên. Thiết kế offline-first: lưu cả giờ thiết bị và giờ server.',
     [
         ('id',           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',           'Khóa chính'),
         ('session_id',   'UUID',        'FK',  'NOT NULL, → sessions.id ON DELETE CASCADE',    'Phiên điểm danh'),
         ('student_id',   'INT',         'FK',  'NOT NULL, → students.id ON DELETE CASCADE',    'Sinh viên điểm danh'),
         ('checkin_time', 'TIMESTAMPTZ', '—',   'NOT NULL',                                     'Giờ điểm danh theo đồng hồ thiết bị'),
         ('sync_time',    'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                      'Giờ đồng bộ lên server'),
         ('status',       'VARCHAR(20)', '—',   "NOT NULL, DEFAULT 'present'\nCHECK(status IN ('present','late','absent','early','on_time'))", 'Trạng thái điểm danh'),
         ('confidence',   'FLOAT',       '—',   'NULLABLE',                                     'Độ tin cậy nhận diện khuôn mặt (0.0–1.0)'),
         ('device_id',    'UUID',        'FK',  'NULLABLE, → devices.id ON DELETE SET NULL',  'Thiết bị dùng để điểm danh'),
         ('minutes_diff', 'INT',         '—',   'NULLABLE',                                     'Số phút chênh lệch so với giờ bắt đầu'),
         ('created_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                     'Thời gian tạo bản ghi'),
         ('deleted_at',   'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                              'Soft delete'),
     ]),
    # ── ATTENDANCE_CONFIGS ──────────────────────────────────────
    ('BẢNG 13: ATTENDANCE_CONFIGS', 'Cấu hình điểm danh riêng cho từng phiên — cho phép admin điều chỉnh thời gian trễ cho phép. Nếu phiên không có config → sử dụng mặc định (early=15, late=15).',
     [
         ('id',              'UUID',       'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',           'Khóa chính'),
         ('session_id',      'UUID',       'FK, UK','NOT NULL, → sessions.id ON DELETE CASCADE',  'Phiên được cấu hình (mỗi phiên tối đa 1 config)'),
         ('room_id',         'UUID',       'FK',  'NULLABLE, → rooms.id ON DELETE SET NULL',     'Phòng áp dụng cấu hình'),
         ('mode',            'VARCHAR(20)','—',   'NULLABLE, DEFAULT NULL\nCHECK(mode IN (\'FIXED\',\'FLEXIBLE\'))', 'Chế độ: FIXED hoặc FLEXIBLE'),
         ('early_allowance', 'INT',        '—',   'NOT NULL, DEFAULT 15\nCHECK(early_allowance BETWEEN 0 AND 120)', 'Phút được phép SỚM trước giờ bắt đầu'),
         ('late_allowance',  'INT',        '—',   'NOT NULL, DEFAULT 15\nCHECK(late_allowance BETWEEN 0 AND 120)',  'Phút được phép TRỄ sau giờ bắt đầu'),
         ('created_at',      'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                      'Thời gian tạo cấu hình'),
         ('updated_at',      'TIMESTAMPTZ','—',   'NOT NULL, DEFAULT NOW()',                      'Thời gian cập nhật gần nhất'),
     ]),
    # ── ATTENDANCE_AUDIT_LOGS ───────────────────────────────────
    ('BẢNG 14: ATTENDANCE_AUDIT_LOGS', 'Nhật ký kiểm toán cho mọi thao tác liên quan đến điểm danh. Ghi lại lịch sử: check-in, chỉnh sửa thủ công, xóa bản ghi.',
     [
         ('id',           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',        'Khóa chính'),
         ('student_id',   'INT',         '—',   'NOT NULL, INDEX',                             'ID sinh viên liên quan'),
         ('session_id',   'UUID',        '—',   'NOT NULL, INDEX',                             'ID phiên điểm danh'),
         ('device_id',    'UUID',        'FK',  'NULLABLE, → devices.id ON DELETE SET NULL',  'Thiết bị thực hiện hành động'),
         ('action',       'VARCHAR(20)', '—',   'NOT NULL\nCHECK(action IN (\'checkin\',\'manual\',\'delete\'))', 'Loại hành động'),
         ('old_status',   'VARCHAR(20)', '—',   'NULLABLE',                                     'Trạng thái trước khi thay đổi'),
         ('new_status',   'VARCHAR(20)', '—',   'NULLABLE',                                     'Trạng thái sau khi thay đổi'),
         ('minutes_diff', 'INT',         '—',   'NULLABLE',                                     'Số phút chênh lệch tại thời điểm check-in'),
         ('created_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW(), INDEX',               'Thời gian thực hiện hành động'),
     ]),
    # ── FACE_EMBEDDINGS ────────────────────────────────────────
    ('BẢNG 15: FACE_EMBEDDINGS', 'Lưu vector đặc trưng khuôn mặt (128 chiều) cho từng sinh viên. Mỗi sinh viên có thể có nhiều embedding (góc chụp khác nhau). Chỉ embedding có is_active=TRUE mới dùng để nhận diện.',
     [
         ('id',           'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',        'Khóa chính'),
         ('student_id',   'INT',         'FK',  'NOT NULL, → students.id ON DELETE CASCADE',   'Sinh viên sở hữu vector khuôn mặt'),
         ('embedding',    'JSON',        '—',   'NOT NULL',                                     'Vector 128 chiều — danh sách số thực (JSON array)'),
         ('is_active',    'BOOLEAN',     '—',   'NOT NULL, DEFAULT TRUE, INDEX',               'Cờ kích hoạt — ACTIVE = dùng để nhận diện'),
         ('quality_score','FLOAT',       '—',   'NULLABLE',                                     'Điểm chất lượng ảnh (0.0–1.0, ≥0.7 = tốt)'),
         ('device_id',    'UUID',        'FK',  'NULLABLE, → devices.id ON DELETE SET NULL',  'Thiết bị chụp khuôn mặt'),
         ('captured_at',  'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                      'Thời điểm chụp khuôn mặt'),
         ('created_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                      'Thời gian lưu embedding'),
         ('updated_at',   'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                      'Thời gian cập nhật gần nhất'),
         ('deleted_at',   'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                              'Soft delete'),
     ]),
    # ── ROOMS ───────────────────────────────────────────────────
    ('BẢNG 16: ROOMS', 'Phòng học / phòng máy — định danh vị trí vật lý của thiết bị và khóa học. Room trở thành trung tâm cho cơ chế anti-cheat (device.room_id = course.room_id).',
     [
         ('id',         'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',   'Khóa chính'),
         ('code',       'VARCHAR(50)', 'UK',  'NOT NULL',                               'Mã phòng, duy nhất (ví dụ: "A101", "PM02")'),
         ('name',       'VARCHAR(255)','—',   'NOT NULL',                               'Tên phòng học'),
         ('building',   'VARCHAR(100)','—',   'NULLABLE',                               'Tòa nhà chứa phòng'),
         ('floor',      'INT',         '—',   'NULLABLE',                               'Tầng của phòng'),
         ('capacity',   'INT',         '—',   'NULLABLE',                               'Sức chứa tối đa của phòng'),
         ('created_at', 'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',               'Thời gian tạo phòng'),
         ('updated_at', 'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',               'Thời gian cập nhật gần nhất'),
         ('deleted_at', 'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                        'Soft delete'),
         ('created_by', 'UUID',        '—',   'NULLABLE',                               'Người tạo phòng'),
         ('updated_by', 'UUID',        '—',   'NULLABLE',                               'Người cập nhật phòng'),
     ]),
    # ── DEVICES ─────────────────────────────────────────────────
    ('BẢNG 17: DEVICES', 'Thiết bị điểm danh (tablet, kiosk) — đăng ký với hệ thống. is_global cho phép dùng ở mọi phòng. status để admin khóa/mở thiết bị.',
     [
         ('id',             'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',         'Khóa chính'),
         ('device_code',    'VARCHAR(50)', 'UK',  'NOT NULL',                                    'Mã thiết bị vật lý (serial), duy nhất'),
         ('device_name',    'VARCHAR(100)','—',   'NULLABLE',                                    'Tên hiển thị của thiết bị'),
         ('room_id',        'UUID',         'FK',  'NULLABLE, → rooms.id ON DELETE SET NULL',   'Phòng mà thiết bị được lắp đặt'),
         ('device_type',    'VARCHAR(50)', '—',   'NOT NULL, DEFAULT \'tablet\'',                 'Loại thiết bị: tablet, kiosk, desktop...'),
         ('is_active',      'BOOLEAN',     '—',   'NOT NULL, DEFAULT TRUE',                     'Cờ kích hoạt thiết bị'),
         ('is_global',      'BOOLEAN',     '—',   'NOT NULL, DEFAULT FALSE',                    'Nếu TRUE → dùng ở mọi phòng'),
         ('status',         'VARCHAR(20)', '—',   'NOT NULL, DEFAULT \'ACTIVE\'\nCHECK(status IN (\'ACTIVE\',\'INACTIVE\'))', 'Trạng thái'),
         ('ip_address',     'VARCHAR(45)', '—',   'NULLABLE',                                    'Địa chỉ IP hiện tại'),
         ('mac_address',     'VARCHAR(17)', '—',   'NULLABLE',                                    'Địa chỉ MAC của thiết bị'),
         ('last_active_at', 'TIMESTAMPTZ', '—',   'NULLABLE',                                    'Hoạt động lần cuối'),
         ('created_at',     'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                    'Thời gian đăng ký thiết bị'),
         ('updated_at',     'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                    'Thời gian cập nhật gần nhất'),
         ('deleted_at',     'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                             'Soft delete'),
         ('created_by',     'UUID',        '—',   'NULLABLE',                                    'Người đăng ký thiết bị'),
         ('updated_by',     'UUID',        '—',   'NULLABLE',                                    'Người cập nhật thiết bị'),
     ]),
    # ── DEVICE_REQUESTS ──────────────────────────────────────────
    ('BẢNG 18: DEVICE_REQUESTS', 'Yêu cầu cấp quyền thiết bị — flow phê duyệt: PENDING → APPROVED / REJECTED. Giáo viên gửi yêu cầu, Admin duyệt để cấp quyền điểm danh hàng loạt.',
     [
         ('id',            'UUID',        'PK',  'NOT NULL, DEFAULT uuid_generate_v4()',            'Khóa chính'),
         ('device_code',   'VARCHAR(50)', '—',   'NOT NULL, INDEX',                                 'Mã thiết bị được yêu cầu'),
         ('device_name',   'VARCHAR(100)','—',   'NULLABLE',                                        'Tên thiết bị được yêu cầu'),
         ('room_id',       'UUID',         'FK',  'NULLABLE, → rooms.id ON DELETE SET NULL',       'Phòng cần cấp quyền (NULL = tất cả phòng)'),
         ('requested_by',  'UUID',         'FK',  'NULLABLE, → users.id ON DELETE SET NULL',      'Người gửi yêu cầu cấp quyền'),
         ('status',        'VARCHAR(20)', '—',   'NOT NULL, DEFAULT \'PENDING\', INDEX\nCHECK(status IN (\'PENDING\',\'APPROVED\',\'REJECTED\'))', 'Trạng thái'),
         ('reviewed_by',   'UUID',         'FK',  'NULLABLE, → users.id ON DELETE SET NULL',      'Admin duyệt yêu cầu'),
         ('reviewed_at',   'TIMESTAMPTZ', '—',   'NULLABLE',                                        'Thời điểm admin duyệt yêu cầu'),
         ('admin_note',    'VARCHAR(255)','—',   'NULLABLE',                                        'Ghi chú của admin khi duyệt/từ chối'),
         ('created_at',    'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                        'Thời gian gửi yêu cầu'),
         ('updated_at',    'TIMESTAMPTZ', '—',   'NOT NULL, DEFAULT NOW()',                        'Thời gian cập nhật gần nhất'),
         ('deleted_at',    'TIMESTAMPTZ', '—',   'NULLABLE, INDEX',                                 'Soft delete'),
     ]),
]

for name, desc, rows in tables_def:
    add_heading(doc, name, 1)
    add_body(doc, desc)
    make_table(doc, HEADERS, rows)

# ═══════════════════════════════════════════════════════════════
#  CONSTRAINTS SUMMARY
# ═══════════════════════════════════════════════════════════════
doc.add_page_break()
add_heading(doc, 'TÓM TẮT CÁC RÀNG BUỘC (CONSTRAINTS)', 1)

constraint_tbl = doc.add_table(rows=1, cols=5)
constraint_tbl.style = 'Table Grid'
constraint_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
for i, h in enumerate(['STT', 'Tên ràng buộc', 'Bảng', 'Kiểu', 'Mô tả']):
    set_cell_bg(constraint_tbl.rows[0].cells[i], '2C3E50')
    p = constraint_tbl.rows[0].cells[i].paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(h)
    run.bold = True
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

constraints = [
    ('1',  'ck_users_role',              'users',               'CHECK',       "role IN ('admin','teacher','student')"),
    ('2',  'ck_session_status',         'sessions',            'CHECK',       "status IN ('scheduled','active','closed')"),
    ('3',  'ck_attendance_status',       'attendances',         'CHECK',       "status IN ('present','late','absent','early','on_time')"),
    ('4',  'ck_day_of_week',             'schedules',           'CHECK',       'day_of_week BETWEEN 1 AND 7'),
    ('5',  'ck_time_slot_order',         'time_slots',          'CHECK',       'end_time > start_time'),
    ('6',  'uq_enrollment_course_student','course_enrollments', 'UNIQUE',     '(course_id, student_id)'),
    ('7',  'uq_attendance_session_student','attendances',       'UNIQUE',     '(session_id, student_id)'),
    ('8',  'uq_schedule_course_day_slot', 'schedules',          'UNIQUE',     '(course_id, day_of_week, time_slot_id)'),
    ('9',  'uq_session_attendance_config','attendance_configs', 'UNIQUE',     '(session_id)'),
    ('10', 'ix_departments_code',         'departments',        'UNIQUE INDEX','(code)'),
    ('11', 'ix_sessions_course_start',    'sessions',           'INDEX',      '(course_id, start_time)'),
    ('12', 'ix_attendance_session_student','attendances',       'INDEX',      '(session_id, student_id)'),
    ('13', 'ix_attendance_checkin_time',  'attendances',        'INDEX',      '(checkin_time)'),
    ('14', 'ix_attendance_status',         'attendances',        'INDEX',      '(status)'),
    ('15', 'ix_face_embeddings_student',   'face_embeddings',   'INDEX',      '(student_id)'),
    ('16', 'ix_device_requests_status',   'device_requests',    'INDEX',      '(status)'),
    ('17', 'ix_users_email',               'users',              'UNIQUE INDEX','(email)'),
    ('18', 'ix_teachers_user_id',          'teachers',           'UNIQUE INDEX','(user_id)'),
    ('19', 'ix_students_user_id',          'students',           'UNIQUE INDEX','(user_id)'),
    ('20', 'ix_refresh_token_jti',         'refresh_tokens',     'UNIQUE INDEX','(token_jti)'),
]

for r_idx, row in enumerate(constraints):
    cells = constraint_tbl.add_row().cells
    bg = 'F2F2F2' if r_idx % 2 == 0 else 'FFFFFF'
    for c_idx, val in enumerate(row):
        set_cell_bg(cells[c_idx], bg)
        p = cells[c_idx].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(val)
        run.font.size = Pt(9)
doc.add_paragraph('')

# ═══════════════════════════════════════════════════════════════
#  STATISTICS
# ═══════════════════════════════════════════════════════════════
add_heading(doc, 'THỐNG KẾ SƠ ĐỒ', 1)
stat_tbl = doc.add_table(rows=1, cols=5)
stat_tbl.style = 'Table Grid'
stat_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
for i, h in enumerate(['Nhóm', 'Bảng', 'Số trường', 'Số FK', 'Số INDEX']):
    set_cell_bg(stat_tbl.rows[0].cells[i], '34495E')
    p = stat_tbl.rows[0].cells[i].paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(h)
    run.bold = True
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

stats = [
    ('Xác thực',        'USERS',              '9',  '—', '2'),
    ('',                'TEACHERS',            '8',  '2', '2'),
    ('',                'STUDENTS',            '10', '3', '2'),
    ('',                'REFRESH_TOKENS',      '8',  '1', '2'),
    ('Học thuật',       'DEPARTMENTS',        '8',  '—', '3'),
    ('',                'STUDENT_GROUPS',      '10', '2', '2'),
    ('',                'COURSES',             '16', '4', '2'),
    ('',                'COURSE_ENROLLMENTS', '4',  '2', '2'),
    ('',                'TIME_SLOTS',          '5',  '—', '1'),
    ('',                'SCHEDULES',           '9',  '2', '2'),
    ('Phiên & Điểm danh','SESSIONS',           '12', '2', '3'),
    ('',                'ATTENDANCES',         '11', '3', '5'),
    ('',                'ATTENDANCE_CONFIGS',  '8',  '2', '1'),
    ('',                'ATTENDANCE_AUDIT_LOGS','9',  '1', '4'),
    ('Khuôn mặt & Thiết bị','FACE_EMBEDDINGS','11', '2', '2'),
    ('',                'ROOMS',               '11', '—', '2'),
    ('',                'DEVICES',             '16', '1', '2'),
    ('',                'DEVICE_REQUESTS',      '12', '3', '3'),
    ('TỔNG',            '18 bảng',              '—',  '31','47'),
]

for r_idx, row in enumerate(stats):
    cells = stat_tbl.add_row().cells
    if row[0] == 'TỔNG':
        bg = 'D5E8D4'
    elif r_idx % 2 == 0:
        bg = 'F2F2F2'
    else:
        bg = 'FFFFFF'
    for c_idx, val in enumerate(row):
        set_cell_bg(cells[c_idx], bg)
        p = cells[c_idx].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(val)
        run.font.size = Pt(9)
        if row[0] == 'TỔNG':
            run.bold = True

# ═══════════════════════════════════════════════════════════════
#  ENTITY RELATIONSHIP SUMMARY
# ═══════════════════════════════════════════════════════════════
doc.add_paragraph('')
add_heading(doc, 'SƠ ĐỒ QUAN HỆ TỔNG QUAN', 1)
rel_tbl = doc.add_table(rows=1, cols=3)
rel_tbl.style = 'Table Grid'
rel_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
for i, h in enumerate(['Quan hệ', 'Kiểu', 'Mô tả']):
    set_cell_bg(rel_tbl.rows[0].cells[i], '2C3E50')
    p = rel_tbl.rows[0].cells[i].paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(h)
    run.bold = True
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

rels = [
    ('USERS → TEACHERS',          '1:1',    'Mỗi User có tối đa 1 hồ sơ Teacher'),
    ('USERS → STUDENTS',          '1:1',    'Mỗi User có tối đa 1 hồ sơ Student'),
    ('USERS → REFRESH_TOKENS',    '1:N',    'Mỗi User có nhiều refresh token'),
    ('DEPARTMENTS → TEACHERS',    '1:N',    'Mỗi Khoa có nhiều Giáo viên'),
    ('DEPARTMENTS → STUDENTS',    '1:N',    'Mỗi Khoa có nhiều Sinh viên'),
    ('DEPARTMENTS → COURSES',     '1:N',    'Mỗi Khoa quản lý nhiều Lớp học phần'),
    ('TEACHERS → STUDENT_GROUPS', '1:N',    'GV chủ nhiệm quản lý nhiều Lớp'),
    ('TEACHERS → COURSES',        '1:N',    'Giáo viên giảng dạy nhiều Lớp HP'),
    ('STUDENT_GROUPS → STUDENTS', '1:N',    'Mỗi Lớp chứa nhiều Sinh viên'),
    ('COURSES → COURSE_ENROLLMENTS','1:N',  'Lớp HP có nhiều Sinh viên đăng ký'),
    ('STUDENTS → COURSE_ENROLLMENTS','1:N', 'Sinh viên đăng ký nhiều Lớp HP'),
    ('COURSES → SCHEDULES',       '1:N',    'Lớp HP có nhiều lịch học trong tuần'),
    ('SCHEDULES → TIME_SLOTS',    'N:1',    'Mỗi lịch gắn với 1 tiết học'),
    ('COURSES → SESSIONS',        '1:N',    'Lớp HP có nhiều phiên điểm danh'),
    ('SCHEDULES → SESSIONS',      '1:N',    'Lịch sinh ra nhiều phiên'),
    ('SESSIONS → ATTENDANCE_CONFIGS','1:1','Mỗi phiên có tối đa 1 cấu hình'),
    ('SESSIONS → ATTENDANCES',    '1:N',    'Phiên có nhiều bản ghi điểm danh'),
    ('STUDENTS → ATTENDANCES',    '1:N',    'Sinh viên có nhiều bản ghi điểm danh'),
    ('DEVICES → ATTENDANCES',     'N:1',    'Thiết bị ghi nhiều lượt điểm danh'),
    ('STUDENTS → FACE_EMBEDDINGS','1:N',   'Sinh viên có nhiều vector khuôn mặt'),
    ('DEVICES → FACE_EMBEDDINGS',  'N:1',   'Thiết bị chụp nhiều khuôn mặt'),
    ('ROOMS → COURSES',           '1:N',    'Phòng chứa nhiều Lớp HP'),
    ('ROOMS → DEVICES',           '1:N',    'Phòng chứa nhiều Thiết bị'),
    ('ROOMS → DEVICE_REQUESTS',   '1:N',    'Phòng nhận nhiều Yêu cầu cấp quyền'),
    ('USERS → DEVICE_REQUESTS (requester)', '1:N','Người gửi nhiều Yêu cầu'),
    ('USERS → DEVICE_REQUESTS (reviewer)',  '1:N','Admin duyệt nhiều Yêu cầu'),
    ('ATTENDANCES → ATTENDANCE_AUDIT_LOGS', '1:N','Mỗi điểm danh sinh ra nhiều audit log'),
]
for r_idx, row in enumerate(rels):
    cells = rel_tbl.add_row().cells
    bg = 'F2F2F2' if r_idx % 2 == 0 else 'FFFFFF'
    for c_idx, val in enumerate(row):
        set_cell_bg(cells[c_idx], bg)
        p = cells[c_idx].paragraphs[0]
        run = p.add_run(val)
        run.font.size = Pt(9)
        cells[c_idx].vertical_alignment = WD_ALIGN_VERTICAL.CENTER

# ─── Save ──────────────────────────────────────────────────────
output_path = r'c:\Users\ADMIN\Desktop\MIS\hrm-flutter_dev_2.0\hrm-flutter_dev_2.0\face_time_keeping\doc\ERD_databasespec_28tables.docx'
doc.save(output_path)
print(f'Done! Saved to: {output_path}')
