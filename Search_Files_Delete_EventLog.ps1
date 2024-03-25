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
    $startDate = Get-Date $dateTimePickerStart.Value.Date
    $endDate = Get-Date $dateTimePickerEnd.Value.Date
    $endDate = $endDate.AddDays(1).AddSeconds(-1)

    $searchFile = $textBoxSearchFile.Text

    $dataTable = New-Object System.Data.DataTable
    $columns = "Время события", "Имя файла", "Пользователь", "Компьютер"
    $columns | ForEach-Object { [void]$dataTable.Columns.Add($_) }

    try {
        Get-WinEvent -FilterHashtable @{LogName="Security";StartTime=$startDate;EndTime=$endDate;Id=4663} | ForEach-Object {
            $event = [xml]$_.ToXml()
            if ($event) {
                $File = $event.Event.EventData.Data | Where-Object { $_.Name -eq 'ObjectName' -and $_.'#text' -notmatch ".*\.tmp" -and $_.'#text' -notmatch ".*~\$.*" -and $_.'#text' -notmatch ".*~lock.*" } | Select-Object -ExpandProperty '#text'
                if (-not [string]::IsNullOrWhiteSpace($searchFile) -and $File -like "*$searchFile*") {
                    $Time = Get-Date $_.TimeCreated -UFormat "%Y-%m-%d %H:%M:%S"
                    $User = $event.Event.EventData.Data | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
                    $Computer = $event.Event.System.computer
                    $row = $dataTable.NewRow()
                    $row."Время события" = $Time
                    $row."Имя файла" = $File
                    $row."Пользователь" = $User
                    $row."Компьютер" = $Computer
                    # Проверяем, что строка не была отфильтрована, прежде чем добавить ее в таблицу
                    if ($File -notmatch ".*\.tmp" -and $File -notmatch ".*~\$.*" -and $File -notmatch ".*~lock.*") {
                        $dataTable.Rows.Add($row)
                    }
                } elseif ([string]::IsNullOrWhiteSpace($searchFile)) {
                    $Time = Get-Date $_.TimeCreated -UFormat "%Y-%m-%d %H:%M:%S"
                    $User = $event.Event.EventData.Data | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
                    $Computer = $event.Event.System.computer
                    $row = $dataTable.NewRow()
                    $row."Время события" = $Time
                    $row."Имя файла" = $File
                    $row."Пользователь" = $User
                    $row."Компьютер" = $Computer
                    # Проверяем, что строка не была отфильтрована, прежде чем добавить ее в таблицу
                    if ($File -notmatch ".*\.tmp" -and $File -notmatch ".*~\$.*" -and $File -notmatch ".*~lock.*") {
                        $dataTable.Rows.Add($row)
                    }
                }
            }
        }
        $dataGridView.DataSource = $dataTable
    } catch {
        Write-Host "An error occurred: $_"
    }
}

# Подключаем функцию к кнопке "Поиск"
$buttonSearchFile.Add_Click({
    Search-Events
})

# Показываем форму
$form.ShowDialog() | Out-Null
