import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "Дедлайны Gozallik"

# Цвета проекта Go'zallik
PRIMARY = "E4178C"       # Розовый бренд
DARK_HEADER = "211A2B"   # Темный для шапки
SUCCESS_BG = "DFF9F2"    # Фон готово
ZEBRA = "FAF8FA"         # Мягкая чересполосица

# Стили
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

# 1. Заголовок
ws.merge_cells("A1:F1")
ws["A1"] = "Go'zallik (Beauty App) — План разработки и дедлайны стартапа"
ws["A1"].font = font_title
ws["A1"].fill = fill_title
ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[1].height = 36

# 2. Подзаголовок с параметрами занятости
ws.merge_cells("A2:F2")
ws["A2"] = "График работы: Пн-Пт — 0 ч (основная работа) | Сб — ~3-4 ч (резерв) | Вс — 7-8 ч (спринт) | Релиз: 1 декабря 2026"
ws["A2"].font = font_subtitle
ws["A2"].fill = PatternFill(start_color="C5238A", end_color="C5238A", fill_type="solid")
ws["A2"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[2].height = 24

# 3. Шапка таблицы
headers = ["Этап", "Модуль / Задачи", "Рабочие даты спринта", "Дедлайн (Демо)", "Ожидаемый результат для фаундера", "Статус"]
ws.append([]) # Пустая строка 3

ws.row_dimensions[4].height = 28
for col_num, header in enumerate(headers, 1):
    cell = ws.cell(row=4, column=col_num, value=header)
    cell.font = font_header
    cell.fill = fill_header
    cell.alignment = align_center

# 4. Данные
data = [
    (
        "Этап 0",
        "Дизайн-система, темы и базовая верстка всех экранов (20 макетов по ТЗ)",
        "10.10 (Сб)",
        "10.10.2026",
        "Готовы все 20 экранов клиента и мастера, шрифты Manrope, токены темы, навигация и переключение ролей",
        "Выполнено"
    ),
    (
        "Этап 1",
        "Авторизация, SMS OTP, анкета профиля и сохранение локальной сессии",
        "11.10 (Вс), 17.10 (Сб), 18.10 (Вс)",
        "18.10.2026",
        "Рабочий ввод +998, SMS код с таймером 00:45, анкета с полом и датой рождения, сессия сохраняется в телефоне",
        "В плане"
    ),
    (
        "Этап 2",
        "Клиентский поиск, фильтрация по категориям, интерактивная карта и профиль салона",
        "24.10 (Сб), 25.10 (Вс)",
        "25.10.2026",
        "Поиск и фильтры по услугам, пины на карте, шторка со списком, карточка салона с табами и мастерами",
        "В плане"
    ),
    (
        "Этап 3",
        "Запись на прием, интерактивный календарь слотов, кредиты и выбор оплаты",
        "31.10 (Сб), 01.11 (Вс)",
        "01.11.2026",
        "Выбор дня и доступного слота времени, списание 34 кредитов, выбор оплаты (депозит / полная, Click/Payme/Uzum)",
        "В плане"
    ),
    (
        "Этап 4",
        "Личный кабинет клиента, «Мои записи» (отмена визита) и динамический QR с таймером",
        "07.11 (Сб), 08.11 (Вс)",
        "08.11.2026",
        "Списки активных и прошедших визитов, отмена за 4 часа, экран QR клиента с обновлением каждые 60 секунд",
        "В плане"
    ),
    (
        "Этап 5",
        "Кабинет Мастера («Usta»): ближайший клиент, управление расписанием и доход",
        "14.11 (Сб), 15.11 (Вс)",
        "15.11.2026",
        "Дашборд мастера, таймер до клиента («Через 20 мин»), открытие/закрытие слотов, расчет комиссии 10% и выручки",
        "В плане"
    ),
    (
        "Этап 6",
        "Камера-сканер QR у мастера, валидация визита, 3 языка (RU, UZ lotin, UZ kirill), темная тема",
        "21.11 (Сб), 22.11 (Вс)",
        "22.11.2026",
        "Реальное сканирование QR камерой, экраны успеха / ошибки с чеклистом, переключение RU / UZ и темы",
        "В плане"
    ),
    (
        "Этап 7",
        "Сквозное E2E тестирование связки Клиент <-> Мастер, багфикс и релизная сборка APK",
        "28.11 (Сб), 29.11 (Вс)",
        "29.11.2026",
        "Полный прогон цикла записи и подтверждения визита, проверка на смартфонах, готовый APK файл",
        "В плане"
    ),
    (
        "ФИНАЛ",
        "ПРЕЗЕНТАЦИЯ И РЕЛИЗ ПРОЕКТА СТАРТАПА",
        "30.11 – 01.12",
        "01.12.2026",
        "Сдача полностью готового, протестированного и функционирующего мобильного приложения",
        "РЕЛИЗ"
    )
]

for row_idx, row_data in enumerate(data, 5):
    ws.row_dimensions[row_idx].height = 42
    is_done = row_data[5] == "Выполнено"
    is_final = row_data[0] == "ФИНАЛ"
    
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

# Ширина колонок
col_widths = {
    "A": 12,
    "B": 44,
    "C": 30,
    "D": 16,
    "E": 48,
    "F": 16,
}
for col_letter, width in col_widths.items():
    ws.column_dimensions[col_letter].width = width

wb.save(r"e:\My projects\Beauty Salons\beauty_salons\Gozallik_Deadlines.xlsx")
print("Saved Gozallik_Deadlines.xlsx successfully!")
