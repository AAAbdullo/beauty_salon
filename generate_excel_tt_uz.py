import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "Gozallik Dedlaynlar"

# Go'zallik brend ranglari
PRIMARY = "E4178C"       # Asosiy pushti
DARK_HEADER = "211A2B"   # To'q rang sarlavha uchun
SUCCESS_BG = "DFF9F2"    # Tayyor yashil fon
ZEBRA = "FAF8FA"         # Qatorlar uchun yumshoq fon

# Shriftlar va stillar
font_title = Font(name="Segoe UI", size=14, bold=True, color="FFFFFF")
font_subtitle = Font(name="Segoe UI", size=9, italic=True, color="FFFFFF")
font_header = Font(name="Segoe UI", size=10, bold=True, color="FFFFFF")
font_bold = Font(name="Segoe UI", size=9, bold=True)
font_regular = Font(name="Segoe UI", size=9)
font_completed = Font(name="Segoe UI", size=9, bold=True, color="1AAA4C")
font_planned = Font(name="Segoe UI", size=9, bold=True, color="C5238A")

fill_title = PatternFill(start_color=PRIMARY, end_color=PRIMARY, fill_type="solid")
fill_header = PatternFill(start_color=DARK_HEADER, end_color=DARK_HEADER, fill_type="solid")
fill_done = PatternFill(start_color=SUCCESS_BG, end_color=SUCCESS_BG, fill_type="solid")
fill_zebra = PatternFill(start_color=ZEBRA, end_color=ZEBRA, fill_type="solid")

thin_border = Border(
    left=Side(style="thin", color="E5DCE2"),
    right=Side(style="thin", color="E5DCE2"),
    top=Side(style="thin", color="E5DCE2"),
    bottom=Side(style="thin", color="E5DCE2")
)

align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)

# 1. Asosiy sarlavha
ws.merge_cells("A1:G1")
ws["A1"] = "Go'zallik (Beauty App / 1Fit modeli) — Texnik topshiriq (TT) asosida ishlab chiqish rejasi"
ws["A1"].font = font_title
ws["A1"].fill = fill_title
ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[1].height = 36

# 2. Ish jadvali shartlari (O'zbekcha)
ws.merge_cells("A2:G2")
ws["A2"] = "Ish tartibi: Dush-Juma — 0 soat (asosiy ish) | Shanba — ~3-4 soat (zaxira) | Yakshanba — 7-8 soat (asosiy sprint) | Reliz: 2026-yil 1-dekabr"
ws["A2"].font = font_subtitle
ws["A2"].fill = PatternFill(start_color="C5238A", end_color="C5238A", fill_type="solid")
ws["A2"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[2].height = 24

# 3. Ustun nomlari
headers = [
    "Bosqich", 
    "TT bo'yicha bandlar",
    "Modul / Vazifalar", 
    "Sprint kunlari", 
    "Dedlayn (Demo)", 
    "Faundor uchun kutilayotgan natija (TT talabi)", 
    "Holati"
]
ws.append([]) # 3-bo'sh qator

ws.row_dimensions[4].height = 28
for col_num, header in enumerate(headers, 1):
    cell = ws.cell(row=4, column=col_num, value=header)
    cell.font = font_header
    cell.fill = fill_header
    cell.alignment = align_center

# 4. To'liq ma'lumotlar (TT bo'yicha)
data = [
    (
        "0-bosqich",
        "Dizayn spetsifikatsiyasi",
        "Dizayn-tizim, mavzular (Themes) va barcha 20 ta ekranning boshlang'ich verstkasi",
        "10.10 (Shanba)",
        "10.10.2026",
        "Mijoz va Usta interfeysi uchun barcha 20 ta ekran, Manrope shrifti, ranglar palitrasi, navigatsiya va rollarni almashtirish tayyor",
        "Bajarildi"
    ),
    (
        "1-bosqich",
        "M-01, M-02",
        "Avtorizatsiya, SMS OTP kod, profil anketasi va foydalanuvchi sessiyasini saqlash",
        "11.10 (Yak), 17.10 (Shan), 18.10 (Yak)",
        "18.10.2026",
        "+998 raqam kiritish, 00:45 taymerli SMS kod, to'liq anketa (ism, familiya, jins, tug'ilgan sana), sessiyani xotirada saqlash",
        "Rejada"
    ),
    (
        "2-bosqich",
        "M-03, M-04, M-05, M-06, M-07",
        "Katalog, qidiruv, filtrlar («kredit bilan», «bugun bo'sh»), xarita va salon/usta sahifasi",
        "24.10 (Shanba), 25.10 (Yakshanba)",
        "25.10.2026",
        "Filtrlar (narx, masofa, kredit), xaritada pinlar, pastki varaq (sheet), salon tafsilotlari, usta profili va xizmatlar narxi",
        "Rejada"
    ),
    (
        "3-bosqich",
        "M-08, M-09, 5-bo'lim (Kredit modeli)",
        "Navbatga yozilish (Booking), 10 daqiqa slotni ushlab turish, kredit formulasida narx va to'lov",
        "31.10 (Shanba), 01.11 (Yakshanba)",
        "01.11.2026",
        "Kun va bo'sh vaqt slotini tanlash (10 daqiqa bron ushlab turiladi), 34 kredit yechilishi, depozit yoki to'liq to'lov (Click, Payme, Uzum)",
        "Rejada"
    ),
    (
        "4-bosqich",
        "M-10, M-11, M-14, K-01...K-10",
        "Mijoz kabineti, «Mening yozuvlarim», 4 soat oldin bekor qilish, muzlatish va 60 soniyali dinamik QR",
        "07.11 (Shanba), 08.11 (Yakshanba)",
        "08.11.2026",
        "Faol va o'tgan navbatlar, 4 soat oldin bekor qilganda kredit qaytishi, obunani muzlatish (7-30 kun), 60 soniyali dinamik QR kod",
        "Rejada"
    ),
    (
        "5-bosqich",
        "S-04, S-05, S-07, S-10, S-11",
        "Usta kabineti («Usta»): eng yaqin mijoz, slotlarni ochish/yopish va daromad hisob-kitobi",
        "14.11 (Shanba), 15.11 (Yakshanba)",
        "15.11.2026",
        "Usta bosh ekrani, mijozgacha taymer («20 daqiqadan so'ng»), slotlarni ochish/yopish, oylik daromad va 10% komissiya hisobi",
        "Rejada"
    ),
    (
        "6-bosqich",
        "6-bo'lim (QR jarayoni), 10-bo'lim (Tillar, Mavzu)",
        "Usta uchun QR skaner kamerasi, tashrif tekshiruvi (-30/+60 daq), 3 ta til, qorong'i mavzu",
        "21.11 (Shanba), 22.11 (Yakshanba)",
        "22.11.2026",
        "Kamera orqali QR skaner, salon va vaqt oralig'i (-30/+60 daq) tekshiruvi, tasdiq / xato ekranlari, 3 ta til (RU, UZ lotin, UZ kirill), Dark Mode",
        "Rejada"
    ),
    (
        "7-bosqich",
        "Qabul mezonlari (60 soniyada bron)",
        "To'liq E2E test (Mijoz <-> Usta), xatoliklarni to'g'irlash va reliz APK yig'ish",
        "28.11 (Shanba), 29.11 (Yakshanba)",
        "29.11.2026",
        "Bron qilishdan to QR tasdiqlanib daromad yozilishigacha to'liq sikl testi, yangi mijoz 60 soniyada bron qila olishi, tayyor APK",
        "Rejada"
    ),
    (
        "YAKUN",
        "12-bo'lim (Reliz)",
        "STARTAP LOYIHASINING RASMIY TAQDIMOTI VA TOPSHIRILISHI",
        "30.11 – 01.12",
        "01.12.2026",
        "TT va dizayn bo'yicha to'liq tayyor, sinovdan o'tgan mobil ilovani faundor va investorlarga topshirish",
        "RELIZ"
    )
]

for row_idx, row_data in enumerate(data, 5):
    ws.row_dimensions[row_idx].height = 44
    is_done = row_data[6] == "Bajarildi"
    is_final = row_data[0] == "YAKUN"
    
    for col_idx, val in enumerate(row_data, 1):
        cell = ws.cell(row=row_idx, column=col_idx, value=val)
        cell.border = thin_border
        
        if is_final:
            cell.fill = PatternFill(start_color="FFE5F3", end_color="FFE5F3", fill_type="solid")
            cell.font = font_bold
        elif is_done:
            cell.fill = fill_done
            cell.font = font_regular
        elif row_idx % 2 == 1:
            cell.fill = fill_zebra
            cell.font = font_regular
        else:
            cell.font = font_regular
            
        if col_idx in (1, 2, 4, 5):
            cell.alignment = align_center
            if col_idx == 5:
                cell.font = font_bold
        elif col_idx == 7:
            cell.alignment = align_center
            if is_done:
                cell.font = font_completed
            elif is_final:
                cell.font = Font(name="Segoe UI", size=10, bold=True, color="E4178C")
            else:
                cell.font = font_planned
        else:
            cell.alignment = align_left

# Ustunlar kengligi
col_widths = {
    "A": 12,
    "B": 18,
    "C": 44,
    "D": 28,
    "E": 16,
    "F": 48,
    "G": 16,
}
for col_letter, width in col_widths.items():
    ws.column_dimensions[col_letter].width = width

wb.save(r"e:\My projects\Beauty Salons\beauty_salons\Gozallik_Dedlaynlar_TT_UZ.xlsx")
print("Saved Gozallik_Dedlaynlar_TT_UZ.xlsx successfully!")
