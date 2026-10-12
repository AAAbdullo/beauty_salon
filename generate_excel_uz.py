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
font_title = Font(name="Segoe UI", size=15, bold=True, color="FFFFFF")
font_subtitle = Font(name="Segoe UI", size=10, italic=True, color="FFFFFF")
font_header = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
font_bold = Font(name="Segoe UI", size=10, bold=True)
font_regular = Font(name="Segoe UI", size=10)
font_completed = Font(name="Segoe UI", size=10, bold=True, color="1AAA4C")
font_planned = Font(name="Segoe UI", size=10, bold=True, color="C5238A")

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
ws.merge_cells("A1:F1")
ws["A1"] = "Go'zallik (Beauty App) — Dasturlash rejasi va dedlaynlar jadvali"
ws["A1"].font = font_title
ws["A1"].fill = fill_title
ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[1].height = 36

# 2. Ish jadvali shartlari (O'zbekcha)
ws.merge_cells("A2:F2")
ws["A2"] = "Ish tartibi: Dush-Juma — 0 soat (asosiy ish) | Shanba — ~3-4 soat (zaxira) | Yakshanba — 7-8 soat (asosiy sprint) | Reliz: 2026-yil 1-dekabr"
ws["A2"].font = font_subtitle
ws["A2"].fill = PatternFill(start_color="C5238A", end_color="C5238A", fill_type="solid")
ws["A2"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[2].height = 24

# 3. Ustun nomlari
headers = [
    "Bosqich", 
    "Modul / Vazifalar", 
    "Sprint kunlari (ish vaqti)", 
    "Dedlayn (Demo)", 
    "Faundor uchun kutilayotgan natija", 
    "Holati"
]
ws.append([]) # 3-bo'sh qator

ws.row_dimensions[4].height = 28
for col_num, header in enumerate(headers, 1):
    cell = ws.cell(row=4, column=col_num, value=header)
    cell.font = font_header
    cell.fill = fill_header
    cell.alignment = align_center

# 4. Ma'lumotlar (O'zbekcha lotin imlosida)
data = [
    (
        "0-bosqich",
        "Dizayn-tizim, mavzular (Themes) va barcha 20 ta ekranning boshlang'ich verstkasi",
        "10.10 (Shanba)",
        "10.10.2026",
        "Mijoz va Usta interfeysi uchun barcha 20 ta ekran, Manrope shrifti, ranglar palitrasi, navigatsiya va rollarni almashtirish tayyor",
        "Bajarildi"
    ),
    (
        "1-bosqich",
        "Avtorizatsiya, SMS OTP kod, profil anketasi va foydalanuvchi sessiyasini saqlash",
        "11.10 (Yak), 17.10 (Shan), 18.10 (Yak)",
        "18.10.2026",
        "+998 raqam kiritish, 00:45 taymerli SMS kod, to'liq anketa (jins, tug'ilgan sana), telefon xotirasida sessiyani saqlash",
        "Rejada"
    ),
    (
        "2-bosqich",
        "Qidiruv, xizmat toifalari bo'yicha saralash, interaktiv xarita va salon sahifasi",
        "24.10 (Shanba), 25.10 (Yakshanba)",
        "25.10.2026",
        "Salonlar va xizmatlarni qidirish, xaritada pinlar, pastki ro'yxat varaqlash (sheet), salon sahifasida ustalar va xizmatlar",
        "Rejada"
    ),
    (
        "3-bosqich",
        "Navbatga yozilish (Booking), interaktiv slotlar taqvimi, kreditlar va to'lov usuli",
        "31.10 (Shanba), 01.11 (Yakshanba)",
        "01.11.2026",
        "Kun va bo'sh vaqt slotlarini tanlash, 34 kredit yechilishi, to'lovni tanlash (depozit / to'liq summa, Click, Payme, Uzum)",
        "Rejada"
    ),
    (
        "4-bosqich",
        "Mijozning shaxsiy kabineti, «Mening yozuvlarim» va har 60 soniyada yangilanuvchi dinamik QR",
        "07.11 (Shanba), 08.11 (Yakshanba)",
        "08.11.2026",
        "Faol va o'tgan navbatlar ro'yxati, 4 soat qolganda bekor qilish, qabulga kelganda ko'rsatiladigan dinamik QR kod",
        "Rejada"
    ),
    (
        "5-bosqich",
        "Usta kabineti («Usta»): eng yaqin mijoz, ish jadvali slotlarini boshqarish va daromad",
        "14.11 (Shanba), 15.11 (Yakshanba)",
        "15.11.2026",
        "Usta bosh ekrani, mijozgacha taymer («20 daqiqadan so'ng»), slotlarni ochish/yopish, oylik daromad va 10% komissiya hisob-kitobi",
        "Rejada"
    ),
    (
        "6-bosqich",
        "Usta uchun QR skaner kamerasi, qabulni tasdiqlash, 3 ta til (RU, UZ lotin, UZ kirill), qorong'i mavzu",
        "21.11 (Shanba), 22.11 (Yakshanba)",
        "22.11.2026",
        "Kamera orqali QR kodni skaner qilish, muvaffaqiyat va xatolik ekranlari, ilovani to'liq 3 tilda ishlatish, Dark Mode",
        "Rejada"
    ),
    (
        "7-bosqich",
        "To'liq E2E testdan o'tkazish (Mijoz <-> Usta), xatoliklarni to'g'irlash va reliz APK yig'ish",
        "28.11 (Shanba), 29.11 (Yakshanba)",
        "29.11.2026",
        "Navbatga yozilishdan to qabul tasdiqlanishigacha to'liq sikl testi, turli telefonlarda tekshirish, o'rnatiluvchi APK fayl",
        "Rejada"
    ),
    (
        "YAKUN",
        "STARTAP LOYIHASINING RASMIY TAQDIMOTI VA TOPSHIRILISHI",
        "30.11 – 01.12",
        "01.12.2026",
        "To'liq tayyor, sinovdan o'tgan, barcha talablarga javob beradigan mobil ilovani faundor va investorlarga topshirish",
        "RELIZ"
    )
]

for row_idx, row_data in enumerate(data, 5):
    ws.row_dimensions[row_idx].height = 42
    is_done = row_data[5] == "Bajarildi"
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
            
        if col_idx in (1, 3, 4):
            cell.alignment = align_center
            if col_idx == 4:
                cell.font = font_bold
        elif col_idx == 6:
            cell.alignment = align_center
            if is_done:
                cell.font = font_completed
            elif is_final:
                cell.font = Font(name="Segoe UI", size=11, bold=True, color="E4178C")
            else:
                cell.font = font_planned
        else:
            cell.alignment = align_left

# Ustunlar kengligi
col_widths = {
    "A": 13,
    "B": 46,
    "C": 32,
    "D": 16,
    "E": 48,
    "F": 16,
}
for col_letter, width in col_widths.items():
    ws.column_dimensions[col_letter].width = width

wb.save(r"e:\My projects\Beauty Salons\beauty_salons\Gozallik_Dedlaynlar_UZ.xlsx")
wb.save(r"e:\My projects\Beauty Salons\beauty_salons\Gozallik_Deadlines.xlsx")
print("Saved Gozallik_Dedlaynlar_UZ.xlsx and updated Gozallik_Deadlines.xlsx successfully!")
