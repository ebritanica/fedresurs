cls

#**************************************************************************************************
function getMessagesbyGuid {
Param([string]$bankrupt_guid, [string]$XmlTag, [string]$TagAttrib)
##Write-Host "================== getMessagesbyGuid: начало =================="
##Write-host "Поиск messages по ключу GUID Банкрота: " $bankrupt_guid

$token | Out-File -FilePath $PSScriptRoot\Bearer.txt -Width 500
$token = Get-Content $PSScriptRoot\Bearer.txt

$Body = @{
    #type='Final2'
    bankruptGUID = $bankrupt_guid
    includeContent = 'true'
    #type='SaleContractResult2,TradeResult'
    #IsLocked=0
    #IsAnnulled=0
    limit=10
    offset=0
}

$parameters = @{
    Method = 'GET'

#Prod
	Uri = 'https://bank-publications-prod.fedresurs.ru/v1/messages?'
    Headers = @{
        Accept = 'application/json'
        Authorization = "Bearer $token"
        'Content-Type' = 'application/json; charset=utf-8'
    }
}

    $messages = Invoke-RestMethod @parameters -Body $body
    ##Write-host 'Найденные messages: '
    ##Write-host '******************************************************************'

    $result = @()
    ##Write-Host "Собщение $messages.pageData.type: " $messages.pageData.type
    $messages.pageData | ForEach-Object {
        
        [xml]$xmlcontent = $_.content
        #write-host $_.content

        $res = $_.content | Select-String -pattern $XmlTag

        if ($res -ne $null){
            #write-host $_.content
            ##write-host "XmlTag :" $XmlTag
            ##write-host "TagAttrib: "$TagAttrib
            # Получить значение атрибута $TagAttrib в Тэге $XmlTag
            $check = $xmlcontent.SelectSingleNode("//" + $XmlTag).GetAttribute($TagAttrib)
            ##Write-Host "check: " $check
            $result += $check
        }
    }

##Write-Host "================== getMessagesbyGuid: конец =================="
##Write-Host "Итог: " ($result -join ", ")
return ($result -join ", ")
}

function getBankrotReports{
    Param([string]$bankrupt_guid, [string]$result_key)

    $bankruptData = getBankruptData -bankrupt_guid $bankrupt_guid -uriType reports

    #Write-Host "Результат поиска по :"  $bankrupt_guid
    #$reports | Format-Table

    #Write-host "Найден bankruptGuid:" $reports.pageData.bankruptGuid
    #Write-host "Статус дела:" $reports.pageData.procedureType
    #Write-host "Содержание (контент) отчета:" $reports.pageData.content

    $result = @()
    ##Write-Host "Всего отчётов: " $bankruptData.pageData.total
    $bankruptData.pageData | ForEach-Object {

        #[xml]$xmlcontent = $_.content
        ##write-host $_.content

        $result += $_.pageData.$result_key

   }

##Write-Host "================== getBankrotReports: конец =================="
##Write-Host "Итог по отчётам: " ($result -join ", ")
return ($result -join ", ")

}

#**************************************************************************************************


function getProcedureByName {
param ($SearchTerm)
# Крутой код !!
# $arr | Where Article -eq 'TShirt' | Where Size -eq 'M' | Select Name
# https://stackoverflow.com/questions/9397137/powershell-multidimensional-arrays

#$SearchTerm = 'CitizenAssetsDisposal FinancialRecovery'

# Разделительные символа в строке между словами
$matches = "[\s|,|;]+"

if ($SearchTerm -match $matches) {
    write-host 'Несколько слов'
    $SearchTerm = [string]$SearchTerm -split "[\s|,|;]+"
} else {
    write-host 'Одно Слово'
    $SearchTerm = $SearchTerm -split $matches
}

#$SearchTerm.GetType()
write-host "Размер массива: " $SearchTerm.Length
write-host "Значение массива: " $SearchTerm[0]

$result=@()

$SearchTerm | ForEach-Object {

#Приложение 4
$source = ConvertFrom-Csv @'
    id, EngName, RusName
    1, FinancialRecovery,Финансовое оздоровление
    2, ExternalManagement, Внешнее управление
    3, Tender,Конкурсное производство
    4, Watching,Наблюдение
    5, CitizenAssetsDisposal,Реализация имущества гражданина
    6, CitizenDebtRestructuring, Реструктуризация долгов гражданин
'@

    $result = $source | Where EngName -eq $SearchTerm | Select RusName

}

##return ($result.id + " | " +  $result.EngName + " | " +  $result.RusName)
return $result.RusName

}

function getXMLTagData {
Param([Parameter(Mandatory=$true)] [PSObject[]]$source, [Parameter(Mandatory=$true)][string]$XmlTag, [string]$TagAttrib )
Write-Host "GetXmlData: Начало ***********************************************************************************************************"

$source.pageData[0] | ForEach-Object {
        
        [xml]$xmlcontent = $_.content
        #write-host "Номер сообщения: " $_.number
        #write-host "Дата сообщения: " $_.datePublish
        #write-host "Тип Сообщения: " $_.type
        #write-host "Процедура: " $_.procedureType

        $res = $_.content | Select-String -pattern $XmlTag
        

        if ($res -ne $null){
            
            #write-host "XmlTag :" $XmlTag
            #write-host "TagAttrib: "$TagAttrib
           
            if ($XmlTag) {
                if ($TagAttrib){
                    $check = $xmlcontent.SelectSingleNode("//" + $XmlTag).GetAttribute($TagAttrib)
                    Write-Host "Поиск по тэгу " $XmlTag " и атрибуту $TagAttrib. Результат: " $check
                } else {
                    $check = $xmlcontent.SelectSingleNode("//" + $XmlTag).InnerText
                    Write-Host "Поиск по тэгу: " $XmlTag ". Результат: " $check
                }
            }

            #Write-Host "getXMLTagData: " $check
            $result += $check
        }
    }

if ($result)  {
    #Write-Host "Итог: " $result
} else {
    Write-Host "По message ничего не найдено"
}

Write-Host "GetXmlData: Конец ***********************************************************************************************************"
return ($result -join ", ")
}

function getReportData {
Param([Parameter(Mandatory=$true)] [PSObject[]]$source, [string]$XmlTag, [string]$TagAttrib, [string]$HeaderInfo )
Write-Host "GetXmlData: Начало ***********************************************************************************************************"

if ($HeaderInfo -and $XmlTag) {
    return "Одновременная выборка по значению HeaderInfo и XmlTag не возможна. Сделайте выборку по одному из этих параметров"
}

if ([string]::IsNullOrEmpty($HeaderInfo) -and [string]::IsNullOrEmpty($XmlTag)) {
    return 'Пустые значения переменных HeaderInfo и XmlTag для поиска. Выборка не возможна.'
}

#Взять только самые свежие данные
$result=''

#write-host "Поиск по данным: " $source.pageData | ConvertTo-Json

if ($source.pageData) {
        Write-Host Есть данные входыне данные $source
   } else {
        Write-Host Входные данные отсутствуют
        return 'Входной массив с данными пуст'
}


$source.pageData[0] | ForEach-Object {

        if ($HeaderInfo) {
            write-host "Номер сообщения: " $_.number
            write-host "Дата сообщения: " $_.datePublish
            write-host "Тип Сообщения: " $_.type
            write-host "Процедура: " $_.procedureType
            $result = $_.$HeaderInfo
        }
        
        
        if ($XmlTag) {

            [xml]$xmlcontent = $_.content
            $res = $_.content | Select-String -pattern $XmlTag

            if ($_.content | Select-String -pattern "MessageData") {
                write-host "Тип сообщения: " $_.type
                write-host "Тип всё сообщение: " ($_ |ConvertTo-Json)
            }
            
            if ($_.content | Select-String -pattern "FinalReport") {}

            if ($res -ne $null){
            
                #write-host "XmlTag :" $XmlTag
                #write-host "TagAttrib: "$TagAttrib
           
                if ($XmlTag) {
                    if ($TagAttrib){
                        $result = $xmlcontent.SelectSingleNode("//" + $XmlTag).GetAttribute($TagAttrib)
                        Write-Host "Поиск по тэгу " $XmlTag " и атрибуту $TagAttrib. Результат: " $check
                    } else {
                        $result = $xmlcontent.SelectSingleNode("//" + $XmlTag).InnerText
                        Write-Host "Поиск по тэгу: " $XmlTag ". Результат: " $check
                    }
                }

                #Write-Host "getXMLTagData: " $result

            }
        }
    } #ForEach-Object

<#
if ($result)  {
    #Write-Host "Итог: " $result
} else {
    Write-Host "По message ничего не найдено"
}
#>

Write-Host "GetXmlData: Конец ***********************************************************************************************************"
return $result
}



function HarvestMessageData {
Param([Parameter(Mandatory=$true)] [PSObject[]]$source, [string]$XmlTag, [string]$TagAttrib )

Write-Host ""
Write-Host "HarvestMessageData: Начало ***********************************************************************************************************"

$result = @()
    Write-host "messages:П1:" $source.pageData.type
    Write-Host ""
    Write-Host "Содержимое ообщения .pageData: "
    #Write-Host  $source.pageData
    Write-Host ""
    $source.pageData | ForEach-Object {
        
        [xml]$xmlcontent = $_.content
        ##write-host $_.content

        $res = $_.content | Select-String -pattern $XmlTag

        if ($res -ne $null){
            #write-host $_.content
            #write-host "XmlTag :" $XmlTag
            #write-host "TagAttrib: "$TagAttrib
            # Получить значение атрибута $TagAttrib в Тэге $XmlTag
            $check = $xmlcontent.SelectSingleNode("//" + $XmlTag).GetAttribute($TagAttrib)
            #Write-Host "check: " $check
            $result += $check
        }
    }

Write-Host "HarvestMessageData: Конец ***********************************************************************************************************"
    #Write-Host "Итог: " ($result -join ", ")

return ($result -join ", ")

}

function HarvestReportData {

Param([Parameter(Mandatory=$true)] [PSObject[]]$source, [Parameter(Mandatory=$true)][string]$XmlTag, [string]$TagAttrib )
Write-Host ""
Write-Host "HarvestReportData: Начало ***********************************************************************************************************"

$result = @()
    Write-host "reports::GUID[O]" $source.pageData.GUID
    Write-host "reports::bankruptGUID[H]" $source.pageData.bankruptGUID
    Write-host "reports::number[O]" $source.pageData.number
    Write-host "reports::datePublish[O]" $source.pageData.datePublish
    Write-host "reports:П3:type[O]" $source.pageData.type
    Write-host "reports:П4:procedureType[H]" $source.pageData.proceduretype
    write-host (getProcedureByName -SearchTerm $source.pageData.proceduretype)
    
    #Получить данные из $source.pageData.content
    $result = getXMLTagData -Source $source -XmlTag 'LegalCaseNumber'
    $result +=getXMLTagData -Source $source -XmlTag 'IsLegalCaseClosed'
    $result +=getXMLTagData -Source $source -XmlTag 'LegalCaseState'

    Write-Host "HarvestReportData: конец ***********************************************************************************************************"

return ($result -join ", ")

}


function getBankruptData {
Param([string]$bankrupt_guid, [ValidateSet("reports", "messages")][string]$uriType)

$token | Out-File -FilePath $PSScriptRoot\Bearer.txt -Width 500
$token = Get-Content $PSScriptRoot\Bearer.txt

switch ($uriType) {

'reports' {

                $Body = @{
                    #type='Final'
                    bankruptGUID = $bankrupt_guid
                    includeContent = 'true'
                    #IsLocked=0
                    #IsAnnulled=0
                    limit = 10
                    offset=0
                }

    }

'messages' {

                $Body = @{
                    #type='Final2'
                    bankruptGUID = $bankrupt_guid
                    includeContent = 'true'
                    #type='SaleContractResult2,TradeResult'
                    #IsLocked=0
                    #IsAnnulled=0
                    limit=10
                    offset=0
                }
                
    }

}

    Write-host "Тип запроса: $uriType"
    $parameters = @{
                    Method = 'GET'

                #Prod
	                Uri = 'https://bank-publications-prod.fedresurs.ru/v1/' + $uriType + '?'
                    Headers = @{
                        Accept = 'application/json'
                        Authorization = "Bearer $token"
                        'Content-Type' = 'application/json; charset=utf-8'
                    }
                }

    $api_answer = Invoke-RestMethod @parameters -Body $body
    Write-Host "Найдено " $uriType ":" $api_answer.total
    Write-Host ""
    
    return $api_answer
}  #end func getBankruptData

#**************************************************************************************************

#текущая дата 
$curdate = (Get-Date).ToString('yyyyMMdd')
$curdate_suffix = (Get-Date -Format "yyyyMMdd_HHmmss")

# Даты для автоматической обработки
$yyyymmdd = (Get-Date).ToString('yyyyMMdd')
$yymmdd = (Get-Date).ToString('yyMMdd')
$yyyy = (Get-Date).ToString('yyyy')
$yy = (Get-Date).ToString('yy')
$mm = (Get-Date).ToString('MM')
$dd = (Get-Date).ToString('dd')

Write-Host "Операция поиска банкротов начата"	
Write-Host "Дата и время: $curdate_suffix"


# Тест: Логин и пароль для подключения по api чтобы получить ключ api тестовые дынные
<#
$body = @{
    login = 'demowebuser'
    password = ''
#>

# Боевой: Логин и пароль для подключения по api чтобы получить ключ api тестовые дынные
$body = @{
    login = 'login_work'
    password = 'pass_work'
}

#Параметры запроса для полчения ключа 
$parameters = @{
    Method = 'POST'
#Test Uri
    #Uri = 'https://bank-publications-demo.fedresurs.ru/v1/auth'

#Production Uri
    Uri = 'https://bank-publications-prod.fedresurs.ru/v1/auth'

    Headers = @{
        Accept = 'text/plain'
        'Content-Type' = 'application/json; charset=utf-8'
    }
}

write-host  ""
write-host "Учётные данные запроса:"
write-host "Логин: " $body.login
write-host  ""
write-host  "Параметры запроса:"
Write-host "Method: "$parameters.Method
Write-host "Uri: " $parameters.Uri
Write-host "Headers.Accept: " $parameters.Headers.Accept
Write-host "Headers.Content-Type: " $parameters.Headers.'Content-Type'
write-host  "========================================================="


# Получить значение ключа api
$result = Invoke-RestMethod @parameters -Body ($body | ConvertTo-Json)

$token | Out-File -FilePath $PSScriptRoot\Bearer.txt -Width 500
$token = Get-Content $PSScriptRoot\Bearer.txt

write-host "Ответ сервера на запроса для получения токена jwt:"
$result | Format-Table

$token = $result.jwt
Write-Host "Токен jwt:"
$token

if ($token -like '') {
    Write-Host "Токен, необходимый для продолжения работы, пуст или не получен с сайта fedresurs.ru "
    Write-Host "Работа скрипта остановлена"
    exit
}

# Адрес отправки запроса для проверки на банкротство =================================================
$parameters = @{
    Method = 'GET'
# Test
	#Uri = 'https://bank-publications-demo.fedresurs.ru/v1/bankrupts?'

#Prod
	Uri = 'https://bank-publications-prod.fedresurs.ru/v1/bankrupts?'
    Headers = @{
        Accept = 'application/json'
        Authorization = "Bearer $token"
        'Content-Type' = 'application/json; charset=utf-8'
    }
}

#Папка где будут размещатся файл с клиентами из АБС
#$workdir_dir = "O:\bankrupt\"

#param( [string]$file )
#$directory = Split-Path -Path $path




$workdir_dir = "C:\automate\bankrupt\test\"

$source_dir = $workdir_dir + "out\"
$dest_dir = $workdir_dir + "chk\"
$archive_dir = $workdir_dir + "arch\" + $curdate

$source_file_name = "cl_flb"
$source_file_extension = ".csv"

#Исходный файл с клиентами
$source_file = $source_dir + $source_file_name + $source_file_extension

if ((test-path $source_file) -eq $false) {
    Write-Host "Файл со списком клиентов не найден: $source_file"
    Start-Sleep -Seconds 0
    exit
}

#$archive_dir= "$PSScriptRoot\archive\$yyyymmdd"

<#
if ( -not (Test-Path $archive_dir)) {
    New-Item -Path $archive_dir -itemType Directory | Out-Null
}
#>


#Удалить предыдущие файлы с результатами если таковые существуют
#Get-ChildItem $dest_dir | Remove-Item #-Include "cl_flb*.*"

Get-ChildItem $dest_dir -Filter "cl_flb*.csv" | Remove-Item

$source_file_archive_name = $source_dir + (Get-Item $source_file).BaseName + "_" + $curdate_suffix + ".csv"

$source_file_archive_name

#Файл в процессе обработки
$dest_file_process = $dest_dir + "cl_flb_process.csv"
$dest_file_process_all = $dest_dir + "cl_flb_process_all.csv"

$dest_file_suffix = "_bankrot_" + $curdate_suffix
$dest_file_suffix_all = "_answerall_" + $curdate_suffix

if ((test-path $dest_file_process) -eq $false) {
    New-Item -path $dest_file_process -force
}

if ((test-path $dest_file_process_all) -eq $false) {
    New-Item -path $dest_file_process_all -force
}

# Итоговый файл
$dest_file_result = $dest_dir + (Get-Item $source_file).BaseName + $dest_file_suffix + ".csv"
$dest_file_result_all = $dest_dir + (Get-Item $source_file).BaseName + $dest_file_suffix_all + ".csv"

#Импортировать csv в массив
$source_clients = Import-CSV -path $source_file -Delimiter ";" -Encoding UTF8 -Header "id","FIO","Ogrn","Ogrnip","Inn","Snils","Birthdate"

#Удалить предыдущие файлы если таковые существуют
if (test-path $dest_file_process) {Remove-Item -path $dest_file_process -force}
if (test-path $dest_file_process_all) {Remove-Item -path $dest_file_process_all -force}
if (test-path $dest_file_result) {Remove-Item -path $dest_file_result -force}
if (test-path $dest_file_result_all) {Remove-Item -path $dest_file_result_all -force}

Write-Host "Получены клиенты из csv"
$source_clients | Format-Table

#*******************************************************************************************************
$found_clients = $source_clients | ForEach-Object {

$body = @{
    Type = "Person"
    Offset = 0
    Limit = 2
}

if ($_.FIO) {$body.Add('Name', $_.FIO)}
if ($_.Ogrn) {$body.Add('Ogrn', $_.Ogrn)}
if ($_.Ogrnip) {$body.Add('Ogrnip', $_.Ogrnip)}
if ($_.Inn) {$body.Add('Inn', $_.Inn)}

#if ($_.Snils) {
    #Привести СНИЛС к нормализации, только цифры. Запрос тогда будет корректным
 #   $digits_only = [regex]::Matches($_.Snils, '\d+')
  #  $body.Add('Snils', $digits_only.value)
#}


if ($_.Birthdate) {$body.Add('Birthdate', $_.Birthdate)}

#Write-Host "Входыне данные клиента для запроса не сервер:"
#write-host $body.Name

$result = Invoke-RestMethod @parameters -Body $body

#Write-Host "Данные по клиенту (первый ответ от сервера):"
#Write-Host "result.total: " $result.total
##Write-Host "$result.pageData.data"
#$result.pageData | ForEach-Object {Write-host $_}

#Массив предыдущий
<#
     id=[string]$_.id
     found = [string]$RESULT.total
     FIO = [string]$_.FIO
     firstName=[string]$result.pageData.data.firstName
     lastName=[string]$result.pageData.data.lastName
     middleName=[string]$result.pageData.data.middleName
     ogrnip=[string]$result.pageData.data.ogrnip
     snils=[string]$result.pageData.data.snils
     birthplace=[string]$result.pageData.data.birthplace
     BirthDate = [string]$birthdate #"2015-11-03T00:00:00.0000000",
     inn=[string]$result.pageData.data.inn
     address=[string]$result.pageData.data.address
     guid=[string]$result.pageData.guid
     r_number=''
     r_procedureType=''
     r_procedureName=''
     r_type=''
     m_DecisionType=''
     r_LegalCaseNumber=''
     r_IsLegalCaseClosed=''
     r_LegalCaseState=''
     m_Number=''
#>

IF ($RESULT.total -eq 0) {

$result_data = @( [pscustomobject]@{
     id=[string]$_.id
     found = [string]$RESULT.total
     FIO = [string]$_.FIO
     firstName=''
     lastName=''
     middleName=''
     ogrnip=[string]$_.Ogrnip
     snils=[string]$_.Snils
     #birthplace=[string]$result.pageData.data.birthplace
     #BirthDate = [string]$birthdate #"2015-11-03T00:00:00.0000000",
     inn=[string]$_.Inn
     #address=[string]$result.pageData.data.address
     guid=''
     r_LegalCaseNumber=''     
     r_IsLegalCaseClosed=''
     r_LegalCaseState=''
     r_number=''
     r_datePublish=''
     r_type_p3=''
     r_procedureType_p4 = ''
     r_procedureName=''

     #Messages data
     m_Number=''
     m_datePublish=''
     m_CaseNumber=''
     m_MessageType_p1=''
     m_DecisionTypeId_p2=''
     m_DecisionTypeName=''
     }
)

}

# Код для тех, кто найден в базе redresurs: проверка на банкротство - банкрот или нет.
if ($RESULT.total -ge 1) {

# **********************************************************************************************************************
#Прежде чем установить признак банкрот или нет, необходимо одготовить переменные

#1.1 Получить все(массив) сообщения по должнику
$bankruptMessages = getBankruptData -bankrupt_guid $result.pageData.guid -uriType "messages"

#1.2 Получить все(массив) отчёты по должнику
$bankruptReports = getBankruptData -bankrupt_guid $result.pageData.guid -uriType "reports"

#2.1 Reports data
     $r_IsLegalCaseClosed=getReportData -source $bankruptReports -XmlTag "IsLegalCaseClosed"
     $r_LegalCaseState=getReportData -source $bankruptReports -XmlTag "LegalCaseState"
     
     $reportBankrupt = $false
     if (($r_IsLegalCaseClosed -eq 'true' ) -or ($r_LegalCaseState -eq 'completed') ) {$reportBankrupt = $true}

#2.2 messages
     $m_MessageType_p1=getReportData -source $bankruptMessages -XmlTag "MessageInfo" -TagAttrib "MessageType"
     $m_DecisionTypeId_p2=getReportData -source $bankruptMessages -XmlTag "DecisionType" -TagAttrib "Id"

     $messageBankrupt = $false
     #if (($m_MessageType_p1 -eq 'ArbitralDecree' ) -or ($m_DecisionTypeId_p2 -in @(25,19))) {$messageBankrupt = $true}

#3.1 Итог банкрот или нет?
     $found=1
     #if ($reportBankrupt -or $messageBankrupt) {$found=1}
# Далее, значения полученных переменных используются ниже по коду при подстановке в поля массива

# **********************************************************************************************************************


$result_data = @( [pscustomobject]@{
     id=[string]$_.id
     found = $found
     FIO = [string]$_.FIO
     firstName=[string]$result.pageData.data.firstName
     lastName=[string]$result.pageData.data.lastName
     middleName=[string]$result.pageData.data.middleName
     ogrnip=[string]$result.pageData.data.ogrnip
     snils=[string]$result.pageData.data.snils
     #birthplace=[string]$result.pageData.data.birthplace
     #BirthDate = [string]$birthdate #"2015-11-03T00:00:00.0000000",
     inn=[string]$result.pageData.data.inn
     #address=[string]$result.pageData.data.address
     guid=[string]$result.pageData.guid
     r_LegalCaseNumber=getReportData -source $bankruptReports -XmlTag "LegalCaseNumber"     
     r_IsLegalCaseClosed=getReportData -source $bankruptreports -XmlTag "IsLegalCaseClosed"
     r_LegalCaseState=getReportData -source $bankruptReports -XmlTag "LegalCaseState"
     r_number=getReportData -source $bankruptReports -HeaderInfo "number"
     r_datePublish=getReportData -source $bankruptReports -HeaderInfo "datePublish"
     r_type_p3=getReportData -source $bankruptReports -HeaderInfo "type"
     r_procedureType_p4 = $r_procedureType_p4=getReportData -source $bankruptReports -HeaderInfo "procedureType"
     r_procedureName=getProcedureByName($r_procedureType_p4)

     #Messages data
     m_Number=getReportData -source $bankruptMessages -HeaderInfo "Number"
     m_datePublish=getReportData -source $bankruptMessages -HeaderInfo "datePublish"
     m_CaseNumber=getReportData -source $bankruptMessages -XmlTag "CaseNumber"
     #m_type=getReportData -source $bankruptMessages  -HeaderInfo "type"
     #На заметку:Выяснилось, что m_type эквивалентно m_MessageType_p1
     m_MessageType_p1=$m_MessageType_p1 #=getReportData -source $bankruptMessages -XmlTag "MessageInfo" -TagAttrib "MessageType"
     m_DecisionTypeId_p2=$m_DecisionTypeId_p2 #=getReportData -source $bankruptMessages -XmlTag "DecisionType" -TagAttrib "Id"
     m_DecisionTypeName=getReportData -source $bankruptMessages -XmlTag "DecisionType" -TagAttrib "Name"

     }
     
     #Write-Host ($m_info| convertto-json)
)


    #Записать данные в файл только с банкротами
    if ($found) {
        $result_data |  Export-CSV $dest_file_process -append -NoTypeInformation -Encoding UTF8 -Delimiter ";"
    }
}

    #Записать данные в файл всех клиентов
    $result_data |  Export-CSV $dest_file_process_all -append -NoTypeInformation -Encoding UTF8 -Delimiter ";"

#write-host $RESULT.total $_.id $_.FIO
Start-Sleep -Seconds 0.4

}

#Переименовать файл в итоговый
Rename-Item -Path $dest_file_process -NewName $dest_file_result
Rename-Item -Path $dest_file_process_all -NewName $dest_file_result_all
Rename-Item -Path $source_file -NewName $source_file_archive_name

Copy-Item -Path $dest_file_result_all -Destination ($dest_dir + $source_file_name + $source_file_extension)
#Move-Item -Path $dest_file_result -Destination $archive_dir
#Move-Item -Path $dest_file_result_all -Destination $archive_dir
Move-Item -Path $source_file_archive_name -Destination $dest_dir


Write-Host "Операция поиска банкротов окончена"

