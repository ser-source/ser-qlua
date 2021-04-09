-------------------------------  !!!   ТОЛЬКО ДЛЯ АКЦИЙ    !!!  -----------------------------------------
-- Написано в NotePad++ шрифтом Arial 11
-- Переработано из nick-nh/qlua 
---------------------------------------------------------------------------------------------------------------------
-- ПЕРЕМЕННЫЕ  настройки на счёт
CLIENT_CODE				= "?????"					-- Клиенткий код
ACCOUNT						= "???-????????"		-- Идентификатор счета
FIRM_ID							= "MC000???????"		-- Код фирмы можно взять из заголовка таблицы Купить/Продать

---------------------------------------------------------------------------------------------------------------------
--РАБОЧИЕ ПЕРЕМЕННЫЕ  (менять не нужно)
IsRun								= true				-- Флаг поддержания работы скрипта
t_id									= nil				-- Указатель на таблицу

BLACK							= RGB( 0, 0, 0 )
WHITE							= RGB( 240, 240, 240 )
GREEN							= RGB( 165, 210, 128 )
RED								= RGB( 255, 168, 164 )
GREY								= RGB( 192, 192, 192 )
PALERED						= RGB( 200, 100, 100 )
PALEGREEN					= RGB( 140, 180, 128 )
DARKRED						= RGB( 140, 100, 100 )
DARKGREEN					= RGB( 100, 140, 100 )
YELLOW						= RGB( 255, 255, 0 )
---------------------------------------------------------------------------------------------------------------------
SEC_CODE					= ''								-- Код бумаги в расчете
CLASS_CODE				= ''								-- Ее CLASS_CODE
SCALE							= 0								-- Ее точность
STEP								= 0								-- Ее шаг цены
LOTSIZE							= 1								-- Ее размер лота
SEC_CODES					= {}								-- Таблица для расчетов

PARAMS_FILE_NAME	= getScriptPath().."\\scriptMonitor.csv"	-- ИМЯ ФАЙЛА настроек
---------------------------------------------------------------------------------------------------------------------
----------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ --
----------------------------------------------------
function FiveDaysAgo( i )
	local ds		= SEC_CODES[  'dayDS' ][ i ]
	local lb		= ds:Size()

	local period	= 5
	local HHV	= ds:H(  lb - 1 )
	local LLV	= ds:L(  lb - 1 )
	for i = 1, period  do
		if  HHV  < ds:H(  lb - i )	then	HHV	= ds:H(  lb - i )	end
		if  LLV	 > ds:L(  lb - i )	then	LLV	= ds:L(  lb - i )	end
	end
	return  ds:C( lb - 5 ), HHV, LLV
end

--------------------------------------------------------------------------------------------------------------------- 
 function GetTotalnet()

	if IsRun == false or isConnected() ~= 1 then 	return 0, 0, 0, 0, 0 end

	local result		= getBuySellInfo( FIRM_ID, CLIENT_CODE, CLASS_CODE, SEC_CODE , 0 )
	if result == nil		then 	return 0, 0, 0, 0, 0, 0 end
	local bal		= tonumber( result.balance		or "0" ) 
	local val		= tonumber( result.value			or "0" )
	local prof	= tonumber( result.profit_loss	or "0" )

	return bal /LOTSIZE,																-- Позиция
				val,																				-- Оценка
				prof,																				-- Прибыль / Убыток в деньгах
				tonumber( result.can_buy		or "0" ) / LOTSIZE,		-- Можно купить
				tonumber( result.can_sell		or "0" ) / LOTSIZE,		-- Можно продать
				(val - prof ) / bal															-- Цена приобретения
 end 

---------------------------------------------------------------------------------------------------------------------
function OnInit()	-- Первый  вход (ВЫЗЫВАЕТСЯ QUIKом один раз в начале)
	local ParamsFile = io.open( PARAMS_FILE_NAME, "r" )
	if ParamsFile == nil then
		IsRun = false
		message( "Monitor:OnInit: Не удалость прочитать файл настроек"..PARAMS_FILE_NAME.." !!!" )
		return false
	end

	if isConnected() ~= 1 then
		IsRun = false
		message( "Monitor:OnInit: Нет подключения к серверу !!!" )
		return false
	end
	
	SEC_CODES[ 'class_codes' ]					= {} 			-- CLASS_CODE
	SEC_CODES[ 'names' ]	 						= {} 			-- имена бумаг
	SEC_CODES[ 'sec_codes' ]						= {} 			-- коды бумаг
	SEC_CODES[ 'isMessage' ]						= {} 			-- выводить сообщения(не используется)
	SEC_CODES[ 'isPlaySound' ]					= {} 			-- проигрывать звук(не используется)
	SEC_CODES[ 'dayDS' ]							= {} 			-- данные  по инструменту 1???  день
	SEC_CODES[ 'LOTSIZE' ]						= {}			-- размер лота
	SEC_CODES[ 'STEP' ]								= {} 			-- шаг цены
	SEC_CODES[ 'SCALE' ]							= {} 			-- точность

	local lineCount = 0
	for line in ParamsFile:lines() do
		lineCount = lineCount + 1
		if lineCount > 1 and line ~= "" then
			local per1, per2, per3, per4, per5 = line:match("%s*(.*);%s*(.*);%s*(.*);%s*(.*);%s*(.*)")
			local st = tonumber( getParamEx( per1, per3, "SEC_PRICE_STEP" ).param_value or 1 ) 
			local ls = tonumber( getParamEx( per1, per3,"lotsize" ).param_value or 1 ) 
			local sc = getSecurityInfo( per1, per3 ).scale or 2
			
			SEC_CODES[ 'class_codes' ][ lineCount-1 ]					= per1 							-- CLASS_CODE
			SEC_CODES[ 'names' ][ lineCount-1 ]								= per2 							-- имена бумаг
			SEC_CODES[ 'sec_codes' ][ lineCount-1 ]						= per3								-- коды бумаг
			SEC_CODES[ 'isMessage' ][ lineCount-1 ]						= tonumber(per4) 			-- выводить сообщения
			SEC_CODES[ 'isPlaySound' ][ lineCount-1 ]					= tonumber(per5) 			-- проигрывать звук
			SEC_CODES[ 'dayDS' ][ lineCount-1 ]								= {} 									-- данные  по инструменту 1???  день
			SEC_CODES[ 'LOTSIZE' ][ lineCount-1 ]							=  ls
			SEC_CODES[ 'STEP' ][ lineCount-1 ]								=  st
			SEC_CODES[ 'SCALE' ][ lineCount-1 ]								=  sc

		end
	end
	ParamsFile:close()	

--  Данные дневного интервала	
	for i,v in ipairs(SEC_CODES[ 'sec_codes' ] ) do

		local ds = CreateDataSource( SEC_CODES[ 'class_codes' ][ i ], v, INTERVAL_D1 )
		if ds == nil then
			message( "Monitor "..v..': ОШИБКА получения доступа к свечам! '..Error )
			IsRun = false
		return
		end
		
		 if ds:Size() == 0 then 
			ds:SetEmptyCallback()
		end
		SEC_CODES[ 'dayDS' ][ i ] = ds
	end		--

	CreateTable()					-- Создает таблицу
end 

---------------------------------------------------------------------------------------------------------------------
function main()				-- Функция, реализующая основной поток выполнения в скрипте
	while IsRun do			-- Бескрнечный цикл, пока IsRun == true 
		if isConnected() == 1	then FillTable() end 
		sleep(100)
	end
end
		
---------------------------------------------------------------------------------------------------------------------
function OnStop()		-- ВЫЗЫВАЕТСЯ ТЕРМИНАЛОМ QUIK при остановке скрипта
	IsRun = false
	if	t_id ~= nil then	DestroyTable( t_id )	end
end
		
---------------------------------------------------------------------------------------------------------------------
function CreateTable()		-- Функция создает таблицу
	t_id = AllocTable()			-- Получает id для создания таблицы
	
	AddColumn( t_id, 0,	"Инструмент",	true, QTABLE_STRING_TYPE,	10)
	AddColumn( t_id, 1,	"%",						true, QTABLE_DOUBLE_TYPE,	6	)	
	AddColumn( t_id, 2,	"Цена",				true, QTABLE_DOUBLE_TYPE,	8	)
	AddColumn( t_id, 3,	"",						true, QTABLE_DOUBLE_TYPE,	1	)
	AddColumn( t_id, 4,	"Мин ц.",				true, QTABLE_DOUBLE_TYPE,	8	)
	AddColumn( t_id, 5,	"Макс ц.",			true, QTABLE_DOUBLE_TYPE,	8	)
	AddColumn( t_id, 6,	"",						true, QTABLE_DOUBLE_TYPE,	1	)	
	AddColumn( t_id, 7,	"%Week",			true, QTABLE_DOUBLE_TYPE,	7	)
	AddColumn( t_id, 8,	"Поз.",					true, QTABLE_INT_TYPE,			6	)
	AddColumn( t_id, 9,	"Цена пр",			true, QTABLE_DOUBLE_TYPE,	8	)
	AddColumn( t_id, 10,	"Оценка",			true, QTABLE_DOUBLE_TYPE,	9	)
	AddColumn( t_id, 11,	"Профит",			true, QTABLE_DOUBLE_TYPE,	8	)	
	AddColumn( t_id, 12,	"Проф %",			true, QTABLE_DOUBLE_TYPE,	8	)	
	AddColumn( t_id, 13,	"Куп.",					true, QTABLE_INT_TYPE,			6	)	
	AddColumn( t_id, 14,	"Прод.",				true, QTABLE_INT_TYPE,			6	)
	AddColumn( t_id, 15,	"",						true, QTABLE_DOUBLE_TYPE,	1	)
	AddColumn( t_id, 16,	"Спрос",				true, QTABLE_DOUBLE_TYPE,	10 )
	AddColumn( t_id, 17,	"Предл.",				true, QTABLE_DOUBLE_TYPE,	10 )
	AddColumn( t_id, 18,	"",						true, QTABLE_DOUBLE_TYPE,	1	)
	
	t = CreateWindow( t_id )											-- Создает окно таблицы 
	SetWindowCaption( t_id, "Monitor  "..getInfoParam ( "LOCALTIME" ) )			-- Устанавливает заголовок
	SetWindowPos( t_id, 358, 0, 805, 415 )					-- Задает положение и размеры окна таблицы		
																						-- ( 358, 0 )			- левый верхний угол x, y
																						-- ( 805, 415 )		- размер окна x, y
	for i,v in ipairs(SEC_CODES[ 'names' ]) do			-- Добавляет строки 
		InsertRow( t_id, i )
		SetCell( t_id, i, 0, v )												-- Инструмент				 - колонка 0 (не меняется при расчетах)
	end
end

--------------------------------------------------------------------------------------------------------------------- 
function FillTable()		-- Функция заполняет таблицу
	SetWindowCaption( t_id, "Monitor  "..getInfoParam ( "LOCALTIME" ) )			-- Устанавливает заголовок
	for i,v in ipairs( SEC_CODES[ 'sec_codes' ] ) do		
		if IsRun == false or isConnected() ~= 1 then return end

		SEC_CODE			= v
		CLASS_CODE		= SEC_CODES[ 'class_codes' ][ i ]
		STEP						= SEC_CODES[ 'STEP' ][ i ]
		SCALE					= SEC_CODES[ 'SCALE' ][ i ]
		LOTSIZE					= SEC_CODES[ 'LOTSIZE' ][ i ]
		PRICE_FORMAT	= string.format( "%%.0%uf", SCALE )
		
		local last_price			= tonumber(getParamEx( CLASS_CODE, SEC_CODE, "last" ).param_value) or 0
		local open_price			= tonumber(getParamEx( CLASS_CODE, SEC_CODE, "prevprice" ).param_value) or 0
		local lastchange			= tonumber(getParamEx(CLASS_CODE,SEC_CODE,	"lastchange" ).param_value) or 0
		local high_price			= getParamEx( CLASS_CODE, SEC_CODE, "high" ).param_image or ''
		local low_price			= getParamEx( CLASS_CODE, SEC_CODE, "low" ).param_image or ''
		local bid						= tonumber(getParamEx(CLASS_CODE, SEC_CODE, "BIDDEPTHT").param_value) or 0
		local offer					= tonumber(getParamEx(CLASS_CODE, SEC_CODE, "OFFERDEPTHT").param_value) or 0
----------
		openCount, Value, profit, CanBuy, CanSell, wa_pp	= GetTotalnet() 
		local HistDay, HHV, LLV	= FiveDaysAgo( i )
		
------------- ЗАПОЛНЕНИЕ ЯЧЕЕК ----------------
		SetCell( t_id, i, 1, string.format ( "%.02f", lastchange),  lastchange )			-- %												- колонка 1
		SetCell( t_id, i, 2, string.format (PRICE_FORMAT, last_price )) 					-- Текущая цена							- колонка 2

		SetCell( t_id, i, 4, low_price )																			-- Минимум дня							- колонка 4
		SetCell( t_id, i, 5, high_price )																		-- Максимум дня						- колонка 5

		SetCell( t_id, i, 7, string.format ( "%.02f", ( last_price - HistDay ) * 100 / HistDay ))-- % недельный				- колонка 7
		if openCount ~= 0 then
			SetCell( t_id, i, 8, string.format("%d", openCount) )									--Открытая позиция 				- колонка 8
			SetCell( t_id, i, 9, string.format (PRICE_FORMAT,wa_pp )) 					-- Цена приобретения				- колонка 9
			SetCell( t_id, i, 10, string.format ("%.0f", Value) )										-- Оценка текущей позиции		- колонка 10
			SetCell( t_id, i, 11, string.format ("%.0f", profit) )										-- Прибыль									- колонка 11
			SetCell( t_id, i, 12, string.format ("%.02f",profit / Value * 100) )					-- Прибыль %								- колонка 12
		end
		
		SetCell( t_id, i, 13, string.format("%d",CanBuy or 0), CanBuy or 0 )			-- Можно купить							- колонка 13
		SetCell( t_id, i, 14, string.format("%d",CanSell or 0), CanSell or 0 )			-- Можно продать						- колонка 14

		SetCell( t_id, i, 16, string.format("%d",bid))
		SetCell( t_id, i, 17, string.format("%d",offer))
		
------------------------  РАСКРАСКА ЯЧЕЕК ----------------------	
		if (i+1)%4 < 2 then
			fon = GREY
			cdn = PALERED
			cup = PALEGREEN
		else
			fon = WHITE
			cdn = RED
			cup = GREEN	
		end
		
		SetColor(t_id, i,  QTABLE_NO_INDEX, fon, BLACK, fon, BLACK)
--0
		if openCount < 0  then
				SetColor(t_id, i, 0, cdn, BLACK, cdn, BLACK)
		elseif openCount > 0 then
				SetColor(t_id, i, 0, cup, BLACK, cup, BLACK)
		else
				SetColor(t_id, i, 0, fon,  BLACK, fon,  BLACK)
		end
--	1, 2
		if lastchange > 0 then
			SetColor(t_id, i, 1, cup, BLACK, cup, BLACK)
			SetColor(t_id, i, 2, cup, BLACK, cup, BLACK)
		else
			SetColor(t_id, i, 1, cdn, BLACK, cdn, BLACK)
			SetColor(t_id, i, 2, cdn, BLACK, cdn, BLACK)
		end
--	3
		SetColor(t_id, i, 3, RGB( 60, 60, 60 ), BLACK,  RGB( 60, 60, 60 ), BLACK)
-- 4, 5, 6
		SetColor(t_id, i, 4, cdn, BLACK, cdn, BLACK)
		SetColor(t_id, i, 5, cup, BLACK, cup, BLACK)
		SetColor(t_id, i, 6, RGB( 60, 60, 60 ), BLACK,  RGB( 60, 60, 60 ), BLACK)
--	7		
		if last_price > HistDay then
			SetColor(t_id, i, 7, cup, BLACK, cup, BLACK)
		else
			SetColor(t_id, i, 7, cdn, BLACK,cdn, BLACK)
		end
-- 8, 9, 10
		if openCount > 0 then
			SetColor(t_id, i, 8, cup, BLACK,cup, BLACK)
			SetColor(t_id, i, 9, cup, BLACK,cup, BLACK)
			SetColor(t_id, i, 10, cup, BLACK,cup, BLACK)
		elseif openCount == 0 then
			SetColor(t_id, i, 8, fon, BLACK, fon, BLACK)
			SetColor(t_id, i, 9, fon, BLACK, fon, BLACK)
			SetColor(t_id, i, 10, fon, BLACK, fon, BLACK)
		elseif openCount < 0 then
			SetColor(t_id, i, 8, cdn, BLACK, cdn, BLACK)
			SetColor(t_id, i, 9, cdn, BLACK, cdn, BLACK)
			SetColor(t_id, i, 10, cdn, BLACK, cdn, BLACK)
		end
--	11, 12
		if profit > 0 then
			SetColor(t_id, i, 11, cup, BLACK,cup, BLACK)
			SetColor(t_id, i, 12, cup, BLACK,cup, BLACK)
		elseif  profit < 0 then
			SetColor(t_id, i, 11, cdn, BLACK,cdn, BLACK)
			SetColor(t_id, i, 12, cdn, BLACK,cdn, BLACK)
		end
--	15 
		SetColor(t_id, i, 15, RGB( 60, 60, 60 ), BLACK,  RGB( 60, 60, 60 ), BLACK)
--	16, 17
		if bid > offer	then
			SetColor(t_id, i, 16, cup, BLACK,cup, BLACK)
			SetColor(t_id, i, 17, fon, BLACK, fon, BLACK)
		else
			SetColor(t_id, i, 16, fon, BLACK, fon, BLACK)
			SetColor(t_id, i, 17, cdn, BLACK,cdn, BLACK)
		end
--	18		
		SetColor(t_id, i, 18, RGB( 60, 60, 60 ), BLACK,  RGB( 60, 60, 60 ), BLACK)
	end	
end

---------------------------------------------------------------------------------------------------------------------
