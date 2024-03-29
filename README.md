# search_files_delete_audit
Searching for deleted files through the Event Log

* Этот скрипт представляет собой инструмент для анализа журнала событий в операционной системе Windows с целью поиска пользователя который удалил файл. 
* Он позволяет пользователю указать диапазон дат и имя файла для поиска. 
* После выполнения поиска скрипт выводит результаты в виде таблицы, содержащей информацию о времени события удаления файла, имени файла, пользователе, совершившем действие, и имени компьютера, на котором произошло событие. 
* Этот инструмент может быть полезен для отслеживания удаленных файлов и выявления подозрительной активности в системе.
* На текущий момент скрипт ищет Код события 4663 без учета Кода событий 4660
* Соответственно если файл был переименован событие так же отобразиться в логе как Код событий 4663
* В будущем добавить проверку на появление Кода событий 4660 после 4663 и исключить вывод файлов которые были переименованы, а не удалены
* Для того, что бы скрипт работал надо включить в Локаальной Политике безопасности (gpedit.msc На файловом Сервер) Аудит и на папке которая доступна по сети в разделе Безопасности включить аудит файлов на удаление папок и файлов


## Requirements
 * Powershell 2.0

## Version History
```
27.03.2024 
- Оптимизирован Код, Убран Дублирующий Код
- Часть кода перенесена в функцию
- Добавлена обработка исключений в скрипт, для корректной обработки ошибок.

25.03.2025 -  Исправлена фильтрация временных файлов
```
