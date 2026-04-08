"""
Script tạo Chương 3 - Phần Đặc tả Use Case (dạng bảng)
 cho báo cáo tốt nghiệp: Xây dựng hệ thống điểm danh học sinh sử dụng nhận diện khuôn mặt trên thiết bị di động
"""

from docx import Document
from docx.shared import Pt, RGBColor, Cm, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

OUTPUT_PATH = r"c:\Users\ADMIN\Desktop\MIS\hrm-flutter_dev_2.0\hrm-flutter_dev_2.0\face_time_keeping\doc\Chuong3_DacTaUseCase.docx"

# ─── Màu sắc ───────────────────────────────────────────────────────────────
DARK_BLUE  = RGBColor(0x1F, 0x49, 0x7D)   # header bảng
MID_BLUE   = RGBColor(0x2E, 0x74, 0xB5)   # header con
LIGHT_BLUE = RGBColor(0xD6, 0xE4, 0xF0)   # hàng xen kẽ
WHITE      = RGBColor(0xFF, 0xFF, 0xFF)
BLACK      = RGBColor(0x00, 0x00, 0x00)
RED        = RGBColor(0xC0, 0x00, 0x00)
LIGHT_GRAY = RGBColor(0xF2, 0xF2, 0xF2)

# ─── Helpers ───────────────────────────────────────────────────────────────

def set_cell_bg(cell, hex_color: str):
    """Đặt màu nền ô (hex string: 'RRGGBB')"""
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), hex_color)
    tcPr.append(shd)


def set_cell_borders(cell, color_hex='000000', sz=4):
    """Đặt viền ô"""
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        border = OxmlElement(f'w:{side}')
        border.set(qn('w:val'),   'single')
        border.set(qn('w:sz'),     str(sz))
        border.set(qn('w:space'), '0')
        border.set(qn('w:color'),  color_hex)
        tcBorders.append(border)
    tcPr.append(tcBorders)


def set_col_width(cell, width_cm: float):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcW  = OxmlElement('w:tcW')
    tcW.set(qn('w:w'),    str(int(width_cm * 567)))   # 567 = 1cm in twips
    tcW.set(qn('w:type'), 'dxa')
    tcPr.append(tcW)


def add_cell_text(cell, text, bold=False, italic=False, size_pt=11,
                  color: RGBColor = BLACK, align=WD_ALIGN_PARAGRAPH.LEFT,
                  first=False):
    """Thêm text vào cell (first=True: xóa paragraph cũ)"""
    if first:
        cell.text = ''
        p = cell.paragraphs[0]
    else:
        p = cell.add_paragraph()
    p.alignment = align
    run = p.add_run(text)
    run.bold   = bold
    run.italic = italic
    run.font.size  = Pt(size_pt)
    run.font.color.rgb = color
    run.font.name  = 'Times New Roman'
    return p


def set_row_height(row, height_cm: float):
    tr   = row._tr
    trPr = tr.get_or_add_trPr()
    trH  = OxmlElement('w:trHeight')
    trH.set(qn('w:val'),   str(int(height_cm * 567)))
    trH.set(qn('w:hRule'), 'atLeast')
    trPr.append(trH)


def merge_row_cells(table, row_idx, start_col, end_col):
    """Gộp các ô từ start_col → end_col trong một dòng"""
    row = table.rows[row_idx]
    cell_a = row.cells[start_col]
    cell_b = row.cells[end_col]
    cell_a.merge(cell_b)
    return cell_a


def set_table_borders(table, color='2E74B5', sz=6):
    tbl   = table._tbl
    tblPr = tbl.find(qn('w:tblPr'))
    if tblPr is None:
        tblPr = OxmlElement('w:tblPr')
        tbl.insert(0, tblPr)
    tblBorders = OxmlElement('w:tblBorders')
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        b = OxmlElement(f'w:{side}')
        b.set(qn('w:val'),   'single')
        b.set(qn('w:sz'),    str(sz))
        b.set(qn('w:space'), '0')
        b.set(qn('w:color'), color)
        tblBorders.append(b)
    tblPr.append(tblBorders)


# ─── Document setup ─────────────────────────────────────────────────────────

def create_doc():
    doc = Document()

    # Page margins
    for section in doc.sections:
        section.top_margin    = Cm(2.5)
        section.bottom_margin = Cm(2.5)
        section.left_margin   = Cm(3.0)
        section.right_margin  = Cm(2.5)

    # Default paragraph font
    style = doc.styles['Normal']
    style.font.name = 'Times New Roman'
    style.font.size = Pt(13)

    # ─── Helper: heading ───────────────────────────────────────────────────

    def add_heading(text, level=1, before=Cm(0.5), after=Cm(0.3)):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = before
        p.paragraph_format.space_after  = after
        run = p.add_run(text)
        run.bold = True
        run.font.name = 'Times New Roman'
        if level == 1:
            run.font.size = Pt(14)
            run.font.color.rgb = DARK_BLUE
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        elif level == 2:
            run.font.size = Pt(13)
            run.font.color.rgb = DARK_BLUE
        else:
            run.font.size = Pt(13)
            run.font.color.rgb = BLACK
        return p

    def add_body(text, before=Cm(0.2), after=Cm(0.2), bold=False, italic=False,
                 indent= Cm(0)):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = before
        p.paragraph_format.space_after  = after
        p.paragraph_format.left_indent = indent
        run = p.add_run(text)
        run.bold   = bold
        run.italic = italic
        run.font.name = 'Times New Roman'
        run.font.size = Pt(13)
        return p

    # ════════════════════════════════════════════════════════════════════════
    #  CHƯƠNG 3
    # ════════════════════════════════════════════════════════════════════════
    add_heading('CHƯƠNG 3. PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG ĐIỂM DANH HỌC SINH',
                level=1, before=Cm(1.0), after=Cm(0.5))

    # ─── 3.1 3.2 (tóm tắt) ────────────────────────────────────────────────
    add_heading('3.1. Khảo sát và phân tích hiện trạng', level=2)
    add_body(
        'Hệ thống được khảo sát tại môi trường lớp học của trường. Quy trình điểm danh '
        'hiện tại chủ yếu dựa trên phương pháp thủ công (gọi tên, ký sổ), tốn thời gian '
        'và dễ phát sinh sai sót. Những hạn chế chính bao gồm: khó kiểm soát gian lận, '
        'thiếu dữ liệu thống kê tự động, và không đồng bộ giữa các thiết bị. '
        'Từ đó, đề tài đề xuất xây dựng hệ thống điểm danh tự động bằng nhận diện khuôn mặt '
        'trên thiết bị di động nhằm khắc phục các nhược điểm trên.'
    )

    add_heading('3.2. Phân tích yêu cầu hệ thống', level=2)
    add_body(
        'Yêu cầu chức năng chính gồm: (1) Xác thực người dùng; '
        '(2) Quản lý học phần, lớp học, phòng học; '
        '(3) Quản lý phiên điểm danh (tạo, mở, đóng); '
        '(4) Nhận diện khuôn mặt và ghi nhận điểm danh; '
        '(5) Phát hiện giả mạo khuôn mặt (Liveness Detection); '
        '(6) Đồng bộ dữ liệu online/offline; '
        '(7) Quản lý thiết bị điểm danh; '
        '(8) Báo cáo thống kê điểm danh. '
        'Yêu cầu phi chức năng: hiệu năng (thời gian nhận diện < 1 giây), '
        'bảo mật (JWT, chống giả mạo), hoạt động offline, tương thích Android/iOS.'
    )

    # ════════════════════════════════════════════════════════════════════════
    #  3.3 SƠ ĐỒ USE CASE TỔNG QUÁT
    # ════════════════════════════════════════════════════════════════════════
    add_heading('3.3. Sơ đồ Use Case hệ thống', level=2)

    add_body(
        'Hệ thống có ba tác nhân chính: Quản trị viên (Admin), Giáo viên (Teacher), '
        'và Học sinh (Student). Sơ đồ Use Case tổng quát thể hiện các chức năng '
        'mà mỗi tác nhân có thể thực hiện trong hệ thống. '
        'Dưới đây là đặc tả chi tiết của các Use Case quan trọng nhất trong hệ thống.'
    )

    add_heading('3.3.1. Sơ đồ Use Case tổng quát', level=3)
    add_body(
        'Các Use Case chính của hệ thống bao gồm: '
        'UC-01 Đăng nhập hệ thống, UC-02 Quản lý học phần, '
        'UC-03 Quản lý phiên điểm danh, UC-04 Điểm danh bằng khuôn mặt, '
        'UC-05 Phát hiện giả mạo khuôn mặt, UC-06 Đăng ký khuôn mặt, '
        'UC-07 Đồng bộ dữ liệu offline, UC-08 Quản lý thiết bị, '
        'UC-09 Xem báo cáo thống kê.'
    )

    # ─── 3.3.2 Đặc tả UC ────────────────────────────────────────────────
    add_heading('3.3.2. Đặc tả chi tiết các Use Case chính', level=3)

    # ──────────────────────────────────────────────────────────────────
    # BẢNG ĐẶC TẢ USE CASE — dùng hàm tạo bảng
    # ──────────────────────────────────────────────────────────────────

    UC_DATA = [
        # ── UC-01 ────────────────────────────────────────────────────
        {
            'title': 'UC-01: Đăng nhập hệ thống',
            'rows': [
                ('Tên Use Case', 'UC-01: Đăng nhập hệ thống'),
                ('Mã Use Case', 'UC-01'),
                ('Tác nhân', 'Admin, Giáo viên, Học sinh'),
                ('Mô tả', 'Cho phép người dùng đăng nhập vào hệ thống bằng email và mật khẩu. Hệ thống xác thực thông tin đăng nhập và cấp JWT token để truy cập các chức năng tiếp theo.'),
                ('Tiền điều kiện', 'Người dùng đã có tài khoản trong hệ thống. Thiết bị có kết nối mạng (hoặc có token hợp lệ cho đăng nhập offline).'),
                ('Luồng chính', '1. Người dùng mở ứng dụng.\n2. Hệ thống hiển thị màn hình đăng nhập.\n3. Người dùng nhập email và mật khẩu.\n4. Hệ thống xác thực thông tin.\n5. Hệ thống cấp JWT access token và refresh token.\n6. Hệ thống chuyển hướng đến màn hình Dashboard phù hợp với vai trò người dùng.'),
                ('Luồng phụ', 'LB-01: Email hoặc mật khẩu sai → hiển thị thông báo lỗi, cho phép nhập lại.\nLB-02: Tài khoản bị khóa → thông báo tài khoản bị vô hiệu hóa.\nLB-03: Quên mật khẩu → chuyển đến luồng khôi phục mật khẩu.'),
                ('Hậu điều kiện', 'Đăng nhập thành công: người dùng được cấp token và truy cập hệ thống.\nĐăng nhập thất bại: người dùng ở lại màn hình đăng nhập.'),
                ('Yêu cầu phi chức năng', 'Thời gian phản hồi < 2 giây. Bảo mật: mật khẩu được hash bằng bcrypt, JWT có thời hạn 15 phút, refresh token 7 ngày.'),
            ]
        },
        # ── UC-02 ────────────────────────────────────────────────────
        {
            'title': 'UC-02: Quản lý học phần',
            'rows': [
                ('Tên Use Case', 'UC-02: Quản lý học phần'),
                ('Mã Use Case', 'UC-02'),
                ('Tác nhân', 'Admin, Giáo viên'),
                ('Mô tả', 'Cho phép Admin và Giáo viên tạo mới, chỉnh sửa, xóa và xem danh sách học phần. Giáo viên chỉ quản lý học phần do mình phụ trách.'),
                ('Tiền điều kiện', 'Người dùng đã đăng nhập và có vai trò Admin hoặc Giáo viên.'),
                ('Luồng chính', '1. Người dùng chọn mục "Học phần" trên Dashboard.\n2. Hệ thống hiển thị danh sách học phần (lọc theo vai trò).\n3. Người dùng chọn "Thêm mới" / "Sửa" / "Xóa".\n4. Hệ thống xử lý thao tác và cập nhật cơ sở dữ liệu.\n5. Hệ thống thông báo kết quả thành công/thất bại.'),
                ('Luồng phụ', 'LB-01: Xóa học phần đã có sinh viên đăng ký → cảnh báo và yêu cầu xác nhận.\nLB-02: Thêm sinh viên vào học phần → chuyển đến luồng quản lý đăng ký.'),
                ('Hậu điều kiện', 'Thao tác thành công: danh sách học phần được cập nhật.\nThao tác thất bại: hệ thống hiển thị lỗi và giữ nguyên dữ liệu cũ.'),
                ('Yêu cầu phi chức năng', 'Phân quyền rõ ràng: Giáo viên không thể sửa học phần của người khác.'),
            ]
        },
        # ── UC-03 ────────────────────────────────────────────────────
        {
            'title': 'UC-03: Quản lý phiên điểm danh',
            'rows': [
                ('Tên Use Case', 'UC-03: Quản lý phiên điểm danh'),
                ('Mã Use Case', 'UC-03'),
                ('Tác nhân', 'Admin, Giáo viên'),
                ('Mô tả', 'Cho phép Giáo viên tạo phiên điểm danh cho một học phần, mở/đóng phiên điểm danh, và xem danh sách sinh viên đã điểm danh trong phiên.'),
                ('Tiền điều kiện', 'Người dùng đã đăng nhập với vai trò Admin hoặc Giáo viên. Học phần đã được tạo.'),
                ('Luồng chính', '1. Giáo viên chọn học phần cần điểm danh.\n2. Hệ thống hiển thị thông tin học phần và lịch học.\n3. Giáo viên chọn "Mở phiên điểm danh".\n4. Hệ thống tạo phiên mới với trạng thái "active".\n5. Giáo viên quét camera để điểm danh sinh viên.\n6. Giáo viên chọn "Đóng phiên" khi kết thúc.\n7. Hệ thống tổng hợp và lưu kết quả điểm danh.'),
                ('Luồng phụ', 'LB-01: Chưa có sinh viên đăng ký học phần → thông báo và không cho mở phiên.\nLB-02: Quên đóng phiên → hệ thống tự động đóng khi hết giờ học (theo lịch).'),
                ('Hậu điều kiện', 'Phiên điểm danh ở trạng thái "active" hoặc "closed". Danh sách điểm danh được lưu vào cơ sở dữ liệu.'),
                ('Yêu cầu phi chức năng', 'Hỗ trợ chế độ FLEXIBLE (điểm danh mọi lúc) và STRICT (điểm danh trong cửa sổ thời gian).'),
            ]
        },
        # ── UC-04 ────────────────────────────────────────────────────
        {
            'title': 'UC-04: Điểm danh bằng nhận diện khuôn mặt',
            'rows': [
                ('Tên Use Case', 'UC-04: Điểm danh bằng nhận diện khuôn mặt'),
                ('Mã Use Case', 'UC-04'),
                ('Tác nhân', 'Giáo viên (thiết bị điểm danh), Học sinh (đối tượng được điểm danh)'),
                ('Mô tả', 'Giáo viên sử dụng camera trên thiết bị di động để chụp khuôn mặt sinh viên. Hệ thống phát hiện khuôn mặt, trích xuất vector embedding 128 chiều, so khớp với cơ sở dữ liệu đã đăng ký, và ghi nhận điểm danh với trạng thái (present / late / early).'),
                ('Tiền điều kiện', 'Phiên điểm danh đang ở trạng thái "active". Sinh viên đã đăng ký khuôn mặt trong hệ thống. Thiết bị có camera.'),
                ('Luồng chính', '1. Giáo viên mở màn hình camera điểm danh trên ứng dụng Flutter.\n2. Ứng dụng hiển thị khung hướng dẫn (center frame) và liên tục phát hiện khuôn mặt bằng Google ML Kit Face Detection.\n3. Khi khuôn mặt nằm trong khung và đứng yên 2 giây → ứng dụng tự động chụp ảnh.\n4. Ảnh được trích xuất vector embedding 128 chiều bằng mô hình FaceNet (thông qua face_native / ObjectBox).\n5. Vector được so khớp với cơ sở dữ liệu local bằng HNSW index (Cosine similarity).\n6. Nếu similarity ≥ ngưỡng → xác định danh tính sinh viên.\n7. Hệ thống ghi nhận điểm danh vào bảng attendance.\n8. Ứng dụng hiển thị thông tin sinh viên và phát âm thanh thành công.'),
                ('Luồng phụ', 'LB-01: Không phát hiện khuôn mặt sau 3 phút → tự động thoát.\nLB-02: Cosine similarity < ngưỡng → thông báo "Không nhận diện được".\nLB-03: Thiết bị mất mạng → lưu bản ghi vào Hive, đồng bộ khi có mạng.\nLB-04: Hệ thống phát hiện điểm danh trùng (đã điểm danh rồi) → thông báo và bỏ qua.'),
                ('Hậu điều kiện', 'Bản ghi điểm danh được lưu vào bảng attendance với trạng thái phù hợp (present/late/early).'),
                ('Yêu cầu phi chức năng', 'Thời gian nhận diện từ chụp ảnh đến hiển thị kết quả < 1 giây. Độ chính xác nhận diện ≥ 95% (trên tập dữ liệu thực tế).'),
            ]
        },
        # ── UC-05 ────────────────────────────────────────────────────
        {
            'title': 'UC-05: Phát hiện giả mạo khuôn mặt (Liveness Detection)',
            'rows': [
                ('Tên Use Case', 'UC-05: Phát hiện giả mạo khuôn mặt (Liveness Detection)'),
                ('Mã Use Case', 'UC-05'),
                ('Tác nhân', 'Hệ thống (tự động), Học sinh (đối tượng được kiểm tra)'),
                ('Mô tả', 'Trước khi chấp nhận kết quả nhận diện khuôn mặt, hệ thống thực hiện kiểm tra anti-spoofing để phát hiện các hình thức giả mạo như: ảnh in, video phát lại, mặt nạ 3D. Sử dụng phương pháp texture-based (MiniFASNet hoặc tương đương) để phân tích ảnh và phân loại real/spoof.'),
                ('Tiền điều kiện', 'Use Case UC-04 đang thực hiện bước chụp ảnh khuôn mặt.'),
                ('Luồng chính', '1. Ứng dụng chụp ảnh khuôn mặt (sau khi phát hiện face trong center frame).\n2. Ảnh được đưa vào mô hình Liveness Detection (face_native).\n3. Mô hình trả về kết quả phân tích: real (khuôn mặt thật) hoặc spoof (giả mạo).\n4. Nếu isSpoof = True → hệ thống từ chối và hiển thị thông báo "Phát hiện giả mạo".\n5. Nếu isSpoof = False → tiếp tục luồng UC-04 (so khớp embedding).'),
                ('Luồng phụ', 'LB-01: Chất lượng ảnh quá thấp → mô hình trả về unknown → yêu cầu chụp lại.\nLB-02: Khuôn mặt quá gần hoặc quá xa → hệ thống chờ căn chỉnh lại.'),
                ('Hậu điều kiện', 'Spoof pass: tiếp tục so khớp khuôn mặt.\nSpoof fail: kết thúc luồng, không ghi nhận điểm danh.'),
                ('Yêu cầu phi chức năng', 'Thời gian xử lý Liveness < 200ms. Tỷ lệ phát hiện spoof chính xác ≥ 90%.'),
            ]
        },
        # ── UC-06 ────────────────────────────────────────────────────
        {
            'title': 'UC-06: Đăng ký khuôn mặt',
            'rows': [
                ('Tên Use Case', 'UC-06: Đăng ký khuôn mặt'),
                ('Mã Use Case', 'UC-06'),
                ('Tác nhân', 'Admin, Giáo viên, Học sinh'),
                ('Mô tả', 'Cho phép Admin hoặc Giáo viên đăng ký khuôn mặt cho sinh viên mới (chụp nhiều ảnh từ các góc khác nhau, trích xuất embedding và lưu vào ObjectBox trên thiết bị và pgvector trên server).'),
                ('Tiền điều kiện', 'Sinh viên đã tồn tại trong hệ thống. Thiết bị có camera.'),
                ('Luồng chính', '1. Người dùng chọn sinh viên cần đăng ký khuôn mặt.\n2. Hệ thống hướng dẫn chụp 3-5 ảnh từ các góc khác nhau.\n3. Mỗi ảnh được trích xuất vector embedding 128 chiều.\n4. Hệ thống lưu embedding vào ObjectBox (thiết bị) và đồng bộ lên pgvector (server).\n5. Hiển thị thông báo đăng ký thành công.'),
                ('Luồng phụ', 'LB-01: Ảnh chất lượng kém (ánh sáng yếu, khuôn mặt bị che) → yêu cầu chụp lại.\nLB-02: Sinh viên đã có khuôn mặt đăng ký → cập nhật lại embedding mới.'),
                ('Hậu điều kiện', 'Embedding khuôn mặt được lưu thành công vào ObjectBox (local) và pgvector (server). Sinh viên có thể sử dụng điểm danh khuôn mặt.'),
                ('Yêu cầu phi chức năng', 'Mỗi sinh viên cần tối thiểu 3 ảnh hợp lệ để đăng ký. Chất lượng ảnh tối thiểu: khuôn mặt nằm trong khung, không bị nhắm mắt quá lâu.'),
            ]
        },
        # ── UC-07 ────────────────────────────────────────────────────
        {
            'title': 'UC-07: Đồng bộ dữ liệu offline',
            'rows': [
                ('Tên Use Case', 'UC-07: Đồng bộ dữ liệu offline'),
                ('Mã Use Case', 'UC-07'),
                ('Tác nhân', 'Hệ thống (tự động), Giáo viên'),
                ('Mô tả', 'Khi thiết bị mất kết nối mạng, hệ thống tự động lưu các bản ghi điểm danh vào Hive (local storage). Khi có mạng trở lại, hệ thống tự động đồng bộ queue lên server thông qua bulk-check-in API. Hệ thống xử lý xung đột: bản ghi trùng được bỏ qua (idempotent).'),
                ('Tiền điều kiện', 'Thiết bị đã lưu bản ghi điểm danh vào Hive khi offline.'),
                ('Luồng chính', '1. Ứng dụng liên tục kiểm tra trạng thái mạng.\n2. Khi mất mạng: các bản ghi điểm danh được lưu vào Hive với local_id và timestamp.\n3. Khi có mạng trở lại: ứng dụng gọi POST /api/v1/attendance/bulk-check-in với danh sách bản ghi.\n4. Server xử lý từng bản ghi, bỏ qua bản ghi trùng (idempotent).\n5. Server trả về kết quả cho từng bản ghi.\n6. Ứng dụng xóa các bản ghi đã đồng bộ thành công khỏi Hive.'),
                ('Luồng phụ', 'LB-01: Server trả lỗi → bản ghi vẫn nằm trong queue, thử lại sau.\nLB-02: Server vẫn không xử lý được sau nhiều lần → gửi thông báo cho Admin.'),
                ('Hậu điều kiện', 'Tất cả bản ghi trong queue đã được server xử lý. Hive queue trống.'),
                ('Yêu cầu phi chức năng', 'Tự động sync khi mạng khôi phục, không cần thao tác thủ công. Tối đa 3 lần thử lại với backoff.'),
            ]
        },
        # ── UC-08 ────────────────────────────────────────────────────
        {
            'title': 'UC-08: Quản lý thiết bị điểm danh',
            'rows': [
                ('Tên Use Case', 'UC-08: Quản lý thiết bị điểm danh'),
                ('Mã Use Case', 'UC-08'),
                ('Tác nhân', 'Admin'),
                ('Mô tả', 'Cho phép Admin đăng ký thiết bị mới vào hệ thống, phê duyệt yêu cầu truy cập từ thiết bị, và gán thiết bị vào phòng học cụ thể. Mỗi thiết bị chỉ được phép điểm danh trong phòng học được gán.'),
                ('Tiền điều kiện', 'Người dùng đã đăng nhập với vai trò Admin.'),
                ('Luồng chính', '1. Admin chọn mục "Quản lý thiết bị".\n2. Hệ thống hiển thị danh sách thiết bị và trạng thái.\n3. Admin thêm thiết bị mới (device_code, device_name, room).\n4. Admin duyệt yêu cầu truy cập từ thiết bị (DeviceRequest).\n5. Hệ thống cập nhật trạng thái thiết bị (active/inactive).'),
                ('Luồng phụ', 'LB-01: Thiết bị không được phê duyệt → không thể điểm danh.\nLB-02: Gán thiết bị vào phòng học sai → điểm danh bị từ chối với lý do device-room binding failed.'),
                ('Hậu điều kiện', 'Thiết bị ở trạng thái active và được gán đúng phòng học thì mới được phép điểm danh.'),
                ('Yêu cầu phi chức năng', 'Mỗi phòng học có thể có nhiều thiết bị. Mỗi thiết bị chỉ gán được một phòng học.'),
            ]
        },
        # ── UC-09 ────────────────────────────────────────────────────
        {
            'title': 'UC-09: Xem báo cáo thống kê điểm danh',
            'rows': [
                ('Tên Use Case', 'UC-09: Xem báo cáo thống kê điểm danh'),
                ('Mã Use Case', 'UC-09'),
                ('Tác nhân', 'Admin, Giáo viên, Học sinh'),
                ('Mô tả', 'Cho phép người dùng xem báo cáo thống kê điểm danh theo nhiều chiều: theo học phần, theo lớp, theo thời gian, hoặc theo từng sinh viên. Hiển thị tỷ lệ điểm danh (attendance rate), số điểm danh đúng giờ (present/early), số điểm danh muộn (late), và số vắng mặt (absent).'),
                ('Tiền điều kiện', 'Người dùng đã đăng nhập.'),
                ('Luồng chính', '1. Người dùng chọn mục "Báo cáo" trên Dashboard.\n2. Hệ thống hiển thị form lọc (học phần, ngày, lớp).\n3. Người dùng chọn tiêu chí lọc và nhấn "Xem báo cáo".\n4. Hệ thống truy vấn dữ liệu từ bảng attendance và tổng hợp.\n5. Hệ thống hiển thị biểu đồ và bảng số liệu thống kê.'),
                ('Luồng phụ', 'LB-01: Không có dữ liệu điểm danh trong khoảng thời gian → hiển thị thông báo "Không có dữ liệu".\nLB-02: Admin có thể xuất báo cáo ra file CSV.'),
                ('Hậu điều kiện', 'Báo cáo được hiển thị với đầy đủ số liệu thống kê.'),
                ('Yêu cầu phi chức năng', 'Thời gian tải báo cáo < 3 giây cho tập dữ liệu ≤ 10.000 bản ghi.'),
            ]
        },
    ]

    for idx, uc in enumerate(UC_DATA):
        # Tiêu đề UC
        add_heading(uc['title'], level=2, before=Cm(0.6), after=Cm(0.3))

        # Bảng 2 cột: nhãn | giá trị
        tbl = doc.add_table(rows=0, cols=2)
        tbl.alignment = WD_TABLE_ALIGNMENT.LEFT
        set_table_borders(tbl, color='2E74B5', sz=6)

        # Cột 1: 4.5cm, Cột 2: 11cm
        for row_idx in range(len(uc['rows'])):
            row = tbl.add_row()
            set_row_height(row, 0.8)

            label_cell = row.cells[0]
            value_cell = row.cells[1]

            set_col_width(label_cell, 4.0)
            set_col_width(value_cell, 11.5)

            # Xen kẽ màu nền cột nhãn
            if row_idx % 2 == 0:
                set_cell_bg(label_cell, 'D6E4F0')
            else:
                set_cell_bg(label_cell, 'EEF4FA')

            set_cell_bg(value_cell, 'FFFFFF')

            label_text, value_text = uc['rows'][row_idx]

            # Nhãn (bold, đậm)
            add_cell_text(label_cell, label_text,
                          bold=True, size_pt=12, color=DARK_BLUE,
                          align=WD_ALIGN_PARAGRAPH.LEFT, first=True)

            # Giá trị (bình thường)
            add_cell_text(value_cell, value_text,
                          bold=False, size_pt=12, color=BLACK,
                          align=WD_ALIGN_PARAGRAPH.LEFT, first=True)

            set_cell_borders(label_cell, '2E74B5', sz=4)
            set_cell_borders(value_cell, '2E74B5', sz=4)

        doc.add_paragraph()   # khoảng trắng sau bảng

    # ════════════════════════════════════════════════════════════════════════
    #  3.4  Sơ đồ hoạt động
    # ════════════════════════════════════════════════════════════════════════
    add_heading('3.4. Sơ đồ hoạt động (Activity Diagram)', level=2)

    add_body(
        'Sơ đồ hoạt động mô tả quy trình xử lý chính của hệ thống. '
        'Dưới đây là sơ đồ cho hai luồng quan trọng nhất: '
        '(1) Luồng điểm danh bằng khuôn mặt và (2) Luồng đồng bộ dữ liệu offline.'
    )

    add_heading('3.4.1. Sơ đồ hoạt động: Điểm danh bằng khuôn mặt', level=3)
    add_body(
        '1. Giáo viên mở ứng dụng và chọn học phần cần điểm danh.\n'
        '2. Hệ thống kiểm tra phiên điểm danh (phải đang active).\n'
        '3. Giáo viên mở camera điểm danh.\n'
        '4. Ứng dụng liên tục phát hiện khuôn mặt bằng ML Kit.\n'
        '5. Khi khuôn mặt nằm trong khung hướng dẫn → tự động chụp ảnh.\n'
        '6. Mô hình Liveness Detection kiểm tra ảnh (real/spoof).\n'
        '   6a. Nếu Spoof → thông báo lỗi, quay lại bước 4.\n'
        '7. Trích xuất vector embedding 128 chiều.\n'
        '8. So khớp với ObjectBox bằng HNSW + Cosine similarity.\n'
        '   8a. Nếu similarity < ngưỡng → thông báo "Không nhận diện", quay lại bước 4.\n'
        '9. Xác định danh tính sinh viên.\n'
        '10. Kiểm tra đã điểm danh chưa (idempotent).\n'
        '    10a. Nếu đã điểm danh → thông báo và bỏ qua.\n'
        '11. Ghi nhận điểm danh vào bảng attendance.\n'
        '12. Hiển thị kết quả và phát âm thanh thành công.\n'
        '13. Kiểm tra trạng thái mạng.\n'
        '    13a. Nếu offline → lưu vào Hive queue.\n'
        '    13b. Nếu online → gửi lên server ngay.'
    )

    add_heading('3.4.2. Sơ đồ hoạt động: Đồng bộ dữ liệu offline', level=3)
    add_body(
        '1. Hệ thống kiểm tra trạng thái kết nối mạng liên tục.\n'
        '2. Khi mất mạng: các bản ghi điểm danh được lưu vào Hive với:\n'
        '   - local_id (duy nhất trên thiết bị)\n'
        '   - student_id, session_id, timestamp, status, minutes_diff\n'
        '3. Khi mạng khôi phục: hệ thống gọi POST /api/v1/attendance/bulk-check-in.\n'
        '4. Server xử lý từng bản ghi trong batch:\n'
        '   - Kiểm tra session_id + student_id đã tồn tại chưa.\n'
        '   - Nếu đã tồn tại → skip (idempotent), trả skipped=true.\n'
        '   - Nếu chưa → tạo bản ghi mới trong bảng attendance.\n'
        '5. Server trả về kết quả: succeeded, failed, skipped.\n'
        '6. Ứng dụng cập nhật trạng thái queue:\n'
        '   - Xóa các bản ghi đã succeeded khỏi Hive.\n'
        '   - Giữ lại các bản ghi failed để thử lại.'
    )

    # ─── Lưu ───────────────────────────────────────────────────────────
    doc.save(OUTPUT_PATH)
    print(f'Da tao thanh cong: {OUTPUT_PATH}')


if __name__ == '__main__':
    create_doc()
