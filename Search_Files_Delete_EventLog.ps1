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

# Элементы управления
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

$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(10,130)
$dataGridView.Size = New-Object System.Drawing.Size(864,420)
$dataGridView.Anchor = "Top, Bottom, Left, Right"
$dataGridView.AutoSizeColumnsMode = 'Fill'
$dataGridView.AllowUserToAddRows = $false
$form.Controls.Add($dataGridView)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,105)
$progressBar.Size = New-Object System.Drawing.Size(864,20)
$progressBar.Style = 'Marquee'
$progressBar.MarqueeAnimationSpeed = 30
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

function Search-Events {
    $progressBar.Visible = $true
    $form.Refresh()

    $startDate = $dateTimePickerStart.Value.Date
    $endDate = $dateTimePickerEnd.Value.Date.AddDays(1).AddSeconds(-1)
    $searchFile = $textBoxSearchFile.Text.Trim()
    $filePattern = if (![string]::IsNullOrWhiteSpace($searchFile)) { ".*$searchFile.*" } else { ".*" }
    #$regex = [regex]"(?i)(?!.*\.tmp|.*~\$.*|.*~lock.*)$filePattern"
    $regex = [regex]"(?i)^(?!.*(?:\.tmp$|~\$|~lock\.|\\Temp\\)).*$filePattern"

    $dataTable = New-Object System.Data.DataTable
    foreach ($col in @("Время события", "Имя файла", "Пользователь", "Компьютер")) {
        [void]$dataTable.Columns.Add($col)
    }

    # Загружаем события
    $events4660 = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4660; StartTime = $startDate; EndTime = $endDate } -ErrorAction SilentlyContinue
    $events4663 = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4663; StartTime = $startDate; EndTime = $endDate } -ErrorAction SilentlyContinue

    $map4663 = @{}
    foreach ($e in $events4663) {
        $xml = [xml]$e.ToXml()
        $data = $xml.Event.EventData.Data
        $handleId = ($data | Where-Object { $_.Name -eq 'HandleId' }).'#text'
        $file = ($data | Where-Object { $_.Name -eq 'ObjectName' }).'#text'
        $accessMask = ($data | Where-Object { $_.Name -eq 'AccessMask' }).'#text'

        if ($file -and $handleId -and $accessMask -band 0x10000) {
            $map4663[$handleId] = @{
                File = $file
                Time = $e.TimeCreated
                User = ($data | Where-Object { $_.Name -eq 'SubjectUserName' }).'#text'
                Computer = $xml.Event.System.Computer
                Access = $accessMask
            }
        }
    }

    foreach ($e in $events4660) {
        $xml = [xml]$e.ToXml()
        $data = $xml.Event.EventData.Data
        $handleId = ($data | Where-Object { $_.Name -eq 'HandleId' }).'#text'

        if ($handleId -and $map4663.ContainsKey($handleId)) {
            $info = $map4663[$handleId]
            if ($regex.IsMatch($info.File)) {
                $row = $dataTable.NewRow()
                $row."Время события" = $info.Time.ToString("yyyy-MM-dd HH:mm:ss")
                $row."Имя файла" = $info.File
                $row."Пользователь" = $info.User
                $row."Компьютер" = $info.Computer
                $dataTable.Rows.Add($row)
            }
        }
    }

    $dataGridView.DataSource = $dataTable
    $progressBar.Visible = $false
}

$buttonSearchFile.Add_Click({ Search-Events })
$form.ShowDialog() | Out-Null

