#========================================================================
# Name		: Search_Files_Delete_EventLog.ps1
# Author 	: Lunik
# Git	    : https://github.com/xor0x1/search_files_delete_audit
#========================================================================

#========================================================================
# Этот скрипт представляет собой инструмент для анализа журнала событий в операционной системе Windows с целью поиска удаленных файлов. 
# Он позволяет пользователю указать диапазон дат и имя файла для поиска. 
#
# После выполнения поиска скрипт выводит результаты в виде таблицы, содержащей информацию 
# о времени события удаления файла, имени файла, пользователе, совершившем действие, и имени компьютера, на котором произошло событие.
#========================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Создаем форму
$form = New-Object System.Windows.Forms.Form
$form.Text = "Поиск удаленных файлов через Журнал Событий"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"

# Создаем элементы управления для выбора дат
$labelStartDate = New-Object System.Windows.Forms.Label
$labelStartDate.Location = New-Object System.Drawing.Point(10,20)
$labelStartDate.Size = New-Object System.Drawing.Size(100,20)
$labelStartDate.Text = "Начальная дата:"
$form.Controls.Add($labelStartDate)

$dateTimePickerStart = New-Object System.Windows.Forms.DateTimePicker
$dateTimePickerStart.Location = New-Object System.Drawing.Point(120,20)
$form.Controls.Add($dateTimePickerStart)

$labelEndDate = New-Object System.Windows.Forms.Label
$labelEndDate.Location = New-Object System.Drawing.Point(10,47)
$labelEndDate.Size = New-Object System.Drawing.Size(100,20)
$labelEndDate.Text = "Конечная дата:"
$form.Controls.Add($labelEndDate)

$dateTimePickerEnd = New-Object System.Windows.Forms.DateTimePicker
$dateTimePickerEnd.Location = New-Object System.Drawing.Point(120,47)
$form.Controls.Add($dateTimePickerEnd)

# Создаем текстовое поле и кнопку для поиска файла
$labelSearchFile = New-Object System.Windows.Forms.Label
$labelSearchFile.Location = New-Object System.Drawing.Point(10,75)
$labelSearchFile.Size = New-Object System.Drawing.Size(100,20)
$labelSearchFile.Text = "Имя файла:"
$form.Controls.Add($labelSearchFile)

$textBoxSearchFile = New-Object System.Windows.Forms.TextBox
$textBoxSearchFile.Location = New-Object System.Drawing.Point(120,75)
$textBoxSearchFile.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($textBoxSearchFile)

$buttonSearchFile = New-Object System.Windows.Forms.Button
$buttonSearchFile.Location = New-Object System.Drawing.Point(330,75)
$buttonSearchFile.Size = New-Object System.Drawing.Size(75,20)
$buttonSearchFile.Text = "Поиск"
$form.Controls.Add($buttonSearchFile)

# Создаем таблицу для отображения результатов поиска
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(10,100)
$dataGridView.Size = New-Object System.Drawing.Size(864,450)
$dataGridView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$dataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$dataGridView.AllowUserToAddRows = $false
$form.Controls.Add($dataGridView)

# Определяем функцию для поиска событий и вывода в таблицу
function Search-Events {
    $currentDate = Get-Date
    $startDate = $dateTimePickerStart.Value.Date
    $endDate = $dateTimePickerEnd.Value.Date

    # Проверка, что даты начала и окончания не превышают текущую дату
    if ($startDate -gt $currentDate) {
        [System.Windows.Forms.MessageBox]::Show("Начальная дата не может быть больше текущей даты", "Некорректный ввод", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ($endDate -gt $currentDate) {
        [System.Windows.Forms.MessageBox]::Show("Конечная дата не может быть больше текущей даты", "Некорректный ввод", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Проверка корректности дат
    if ($endDate -lt $startDate) {
        [System.Windows.Forms.MessageBox]::Show("Конечная дата должна быть после начальной даты", "Некорректный ввод", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

        # Очистка источника данных перед новым поиском
    $dataTable = New-Object System.Data.DataTable
    $dataGridView.DataSource = $dataTable

    try {
        # Инициализация
        $startDate = $dateTimePickerStart.Value.Date
        $endDate = $dateTimePickerEnd.Value.Date.AddDays(1).AddSeconds(-1)
        $searchFile = $textBoxSearchFile.Text
        $stage = "Инициализация переменных"

        # Создание DataTable
        $dataTable = New-Object System.Data.DataTable

        # Подготовка данных для отображения
        $columns = "Время события", "Имя файла", "Пользователь", "Компьютер"
        foreach ($column in $columns) {
            [void]$dataTable.Columns.Add($column)
        }

        $stage = "Создание DataTable"

        # Запрос к журналу событий
        $filterHashtable = @{
            LogName   = "Security"
            StartTime = $startDate
            EndTime   = $endDate
            Id        = 4663
        }
        $stage = "Запрос к журналу событий"
        $events = Get-WinEvent -FilterHashtable $filterHashtable

        # Обработка событий
        $stage = "Обработка событий"
        foreach ($event in $events) {
            $eventXml = [xml]$event.ToXml()
            $eventData = $eventXml.Event.EventData.Data
            $file = $eventData | Where-Object { $_.Name -eq 'ObjectName' } | Select-Object -ExpandProperty '#text'
            if ($file -and $file -notmatch ".*\.tmp" -and $file -notmatch ".*~\$.*" -and $file -notmatch ".*~lock.*") {
                if ([string]::IsNullOrWhiteSpace($searchFile) -or $file -like "*$searchFile*") {
                    $time = Get-Date $event.TimeCreated -UFormat "%Y-%m-%d %H:%M:%S"
                    $user = $eventData | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
                    $computer = $eventXml.Event.System.Computer
                    $row = $dataTable.NewRow()
                    $row."Время события" = $time
                    $row."Имя файла" = $file
                    $row."Пользователь" = $user
                    $row."Компьютер" = $computer
                    $dataTable.Rows.Add($row)
                }
            }
         }

        $dataGridView.DataSource = $dataTable
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Произошла ошибка на этапе '$stage': " + $_.Exception.Message, "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Подключаем функцию к кнопке "Поиск"
$buttonSearchFile.Add_Click({
    Search-Events
})

# Показываем форму
$form.ShowDialog() | Out-Null
