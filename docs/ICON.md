# Иконка Delta

Исходник знака Δ расположен в `assets/branding/delta.svg`.

Из корня приложения запустите `python tool/generate_icon.py` с Pillow 12.3.0.
Скрипт рисует прямоугольник и многоугольники из SVG и записывает PNG для пяти
плотностей Android и многоразмерную иконку Windows. С Android 8 применяется
adaptive icon с отдельным передним планом. При смене цвета фона обновите
`android/app/src/main/res/values/icon_colors.xml` вместе с SVG.
