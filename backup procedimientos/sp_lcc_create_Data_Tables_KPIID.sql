IF object_ID(N'[dbo].[sp_lcc_create_Data_Tables_KPIID]') IS NOT NULL
              DROP PROCEDURE [dbo ].[sp_lcc_create_Data_Tables_KPIID]
GO

CREATE procedure [dbo].[sp_lcc_create_Data_Tables_KPIID] 
as


----select * into Lcc_Data_HTTPBrowser_oldMet from [dbo].[Lcc_Data_HTTPBrowser]
----select * into Lcc_Data_HTTPTransfer_DL_oldMet from [dbo].[Lcc_Data_HTTPTransfer_DL]
----select * into Lcc_Data_HTTPTransfer_UL_oldMet from [dbo].[Lcc_Data_HTTPTransfer_UL]
----select * into Lcc_Data_Latencias_oldMet from [dbo].[Lcc_Data_Latencias]
----select * into Lcc_Data_YOUTUBE_oldMet from [dbo].[Lcc_Data_YOUTUBE]

--exec dbo.sp_lcc_DropIfExists 'Lcc_Data_HTTPTransfer_DL'
--exec dbo.sp_lcc_DropIfExists 'Lcc_Data_HTTPTransfer_UL'
--exec dbo.sp_lcc_DropIfExists 'Lcc_Data_HTTPBrowser'
--exec dbo.sp_lcc_DropIfExists 'Lcc_Data_YOUTUBE'
--exec dbo.sp_lcc_DropIfExists 'Lcc_Data_Latencias'
--drop table #maxTestID


--select * into Lcc_Data_HTTPTransfer_DL from Lcc_Data_HTTPTransfer_DL_oldMethod
--select * into Lcc_Data_HTTPTransfer_UL from Lcc_Data_HTTPTransfer_UL_oldMethod
--select * into Lcc_Data_HTTPBrowser from Lcc_Data_HTTPBrowser_oldMethod
--select * into Lcc_Data_YOUTUBE from Lcc_Data_YOUTUBE_oldMethod
--select * into Lcc_Data_Latencias from Lcc_Data_Latencias_oldMethod


-- NOTAS MENTALES:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	 ********************************************************
--				[sp_Invalidate_Data_After_Import]		-- OJOOO!!! que hay un proc previo que hace cosas para este proc!!
--	 ********************************************************
--
--	OJO!!:
--		- Si hay cambios en:
--			* los tamaños de ficheros:	1/3/500M
--			* el server:				46.24.7.18
--
--	DL/UL:
--		- Tamaños de ficheros:
--			* CE - 3MB
--			* NC - 500MB		-> activado Fixed Duration
--		- Se anulan los resultados test con thput bajos:
--			* CE:	 384Kbps - DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null, ErrorType='Retainability'
--			* DL_NC: 128Kbps - DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null, ErrorType='Retainability'
--			* UL_NC:  64Kbps - DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null, ErrorType='Retainability'
-- WEB:
--		- Urls brow:
--			* kepler/mkepler
--			* kepler2/mkepler2
--		- Session Time incluye el tiempo de DNS (si procede)
--		- Se anulan test que duren mas de 10s - se supone que lo hace la herramienta pero no es así
--			* (transferT>10000 or sessionT>10000): 		ErrorCause='Transfer Timeout',		ErrorType='Retainability', Throughput=null, sessionT=null,
--			* ([IPAccessT]>10000):						ErrorCause='IP Connection Timeout', ErrorType='Accessibility', Throughput=null,	sessionT=null, IPAccessT=null, transferT=null
-- PING:
--		- Test Ping cuentan sólo los success de 32B en cell DCH
--			* cuando llegue el super job con tiempo de IDLE adecuado, comprobar y eliminar la parte de CELL_DCH
--
-- ALL:
--		- Los calculos KPIs se calculan usando los KPIID dados. 
--		  Para test fallidos, no se reportan valores.
--			* se calculan las columnas "_nu" con la metodología antigua para tener información de dichos test.
--			* para los test de browser, la forma antigua es la misma, calculo a la italiana con los KPIID dados.
--		
--		- INVALIDACIONES VARIAS:
--			*	Invalidación de errores de Herramienta										- invalidReason='LCC UEServer Issues'
--			*	Invalidación de tests no marcados como completados							- invalidReason='LCC Not Completed Test'
--			*	Invalidación de tests Youtube con Freeze tras descargar el video completo	- Invalidreason=Invalidreason+' LCC - Freezing after DL Time'
--			*	Invalidamos los tests de Main o Smaller fuera de contorno					- invalidReason='LCC OutOfBounds'
--			*	Invalidamos los tests marcados como fallo por timeout erróneamente			- invalidReason='LCC UL Wrong Timeout'
--			*	Invalidamos los tests con Error<>0 pero test dado por OK (falta triggers)	- invalidReason=invalidReason + ' || LCC Start/End Time missing (at Session/Test end)'

--		- ANULACIONES FINALES:
--			*	Anulamos todos los valores en el caso de errores (where  errortype is not null):
--					- Lcc_Data_HTTPTransfer_DL / Lcc_Data_HTTPTransfer_UL	->	DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null
--					- Lcc_Data_HTTPBrowser									->  [IP Service Setup Time (s)]=null,	[Transfer Time (s)]=null,	[Session Time (s)]=null,	[DNS Resolution (s)]=null

--		- CONVERSIONES VARIAS:
--			*	Convertimos a completadas los tests marcados como fallo erróneamente - Lcc_Data_HTTPBrowser
--			*	En los test de BROW, los campos _nu se calculan con los KPIID tambien (método antiguo)
--					-[DataTransferred]=b.[DataTransferred_nu],
--					-[ErrorCause]=null,
--					-[ErrorType]=null,
--					-[Throughput]=b.[ThputApp_nu],
--					-[IP Service Setup Time (s)]=b.[IP_AccessTime_sec_nu],
--					-[Transfer Time (s)]=b.[Transfer_Time_sec_nu],
--					-[Session Time (s)]=b.[Session_Time_sec_nu],
--					-[DNS Resolution (s)]=b.[DNSTime_nu]	
--	

--************************************************************************************************************
--****************************************** Declaracion de Varibles *****************************************
--************************************************************************************************************


--	(17) Throughput, Bytes Transferred, Errors y Times 4G/3G - HTTP BROWSER
declare @IPAccessTimeWEB as int = 10400
declare @DNSHostResolution as int = 31100

--	(18) TABLA INTERMEDIA Youtube a partir de la vista de SQ 
declare @Player_Access_Timeout as int = 10
declare @Player_Download_Timeout as int = 10 
declare @Video_Access_Timeout as int = 10
declare @Video_Reproduction_Timeout as int = 23

declare @Player_IPServiceAccess_Time as int = 10620
declare @Video_Transfer as int = 20621
declare @min_Interrupt_Duration as int = 300

--	(19) TABLA INTERMEDIA Results KPI
declare @Downlink_Accessibility as int = 10401	-- El duration no es valido (y no lo sera en la vida) 
declare @Downlink_Retainability as int = 20415
declare @Downlink_Throughput_D1 as int = 30415	-- Bytes Transferred (value3) no valido - Issue: 470000 - pero no van a arreglarlo y VDF esta al tanto. Lo usamos - 20160617

declare @Uplink_Accessibility as int = 10402	-- El duration no es valido (y no lo sera en la vida)
declare @Uplink_Retainability as int = 20416
declare @Uplink_Throughput_D3 as int = 30416	-- Bytes Transferred (value3) no valido - Issue: 470000 - pero no van a arreglarlo y VDF esta al tanto. Lo usamos - 20160617

declare @Downlink_NC_Accessibility as int = 10401		-- El duration no es valido (y no lo sera en la vida) 
declare @Downlink_NC_Retainability as int = 20417
declare @Downlink_NC_MeanDataUserRate as int = 30417	-- Bytes Transferred (value3) no valido - Issue: 470000 - pero no van a arreglarlo y VDF esta al tanto. Lo usamos - 20160617

declare @Uplink_NC_Accessibility as int = 10402		-- El duration no es valido (y no lo sera en la vida)
declare @Uplink_NC_Retainability as int = 20412
declare @Uplink_NC_MeanDataUserRate as int = 30412	-- Bytes Transferred (value3) no valido - Issue: 470000 - pero no van a arreglarlo y VDF esta al tanto. Lo usamos - 20160617

declare @Latency as int = 21000
declare @sizePing as int = 32

declare @Browser_Accessibility as int = 10400
declare @Browser_Retainability as int = 20405
declare @Browser_TCP_Thput as int  = 30405
declare @Browser_SessionTime as int = 10410
declare @DNSTime as int = 31100


--	(20) TABLA INTERMEDIAS DOWNLINK KPI SWISSQUAL
declare @low_Thput_DL_NC as int = 128
declare @low_Thput_DL_CE as int = 384
declare @low_Thput_UL_NC as int = 64
declare @low_Thput_UL_CE as int = 384

--	(22) TABLA INTERMEDIAS BROWSING KPI SWISSQUAL
declare @Browser_Transfer_Timeout as int = 10000
declare @Browser_IP_Connection_Timeout as int = 10000



--************************************************************************************************************************************
--****************************************** CREAMOS LAS TABLAS FINALES VACIAS SI NO EXISTEN *****************************************
--************************************************************************************************************************************

-- Se inicializa el plugin para decodificar de capa 3
exec SQKeyValueInit 'C:\L3KeyValue'

if (select name from sys.all_objects where name='Lcc_Data_HTTPTransfer_DL' and type='U') is null
begin
	CREATE TABLE [dbo].[Lcc_Data_HTTPTransfer_DL](
		[MTU] [char](10) NULL,
		[IMEI] [varchar](50) NULL,
		[CollectionName] [varchar](100) NULL,
		[MCC] [varchar](3) NULL,
		[MNC] [varchar](2) NULL,
		[startDate] [varchar](50) NULL,
		[startTime] [datetime2](3) NULL,
		[endTime] [datetime2](3) NULL,
		[SessionId] [bigint] NULL,
		[FileId] [bigint] NOT NULL,
		[TestId] [bigint] NOT NULL,
		[typeoftest] [varchar](50) NULL,
		[direction] [varchar](20) NULL,
		[info] [varchar](50) NULL,
		[TestType] [varchar](5) NULL,
		[ServiceType] [varchar](1) NULL,
		[IP Access Time (ms)] [int] NULL,
		[DataTransferred] [float] NULL,
		[TransferTime] [float] NULL,
		[ErrorCause] [varchar](1024) NULL,
		[ErrorType] [varchar](1024) NULL,
		[Throughput] [float] NULL,
		[Throughput_MAX] [real] NULL,
		[DataTransferred_PCC] [numeric](38, 1) NULL,
		[TransferTime_PCC] [float] NULL,
		[Throughput_PCC] [float] NULL,
		[Throughput_MAX_PCC] [real] NULL,
		[DataTransferred_SCC1] [numeric](38, 1) NULL,
		[TransferTime_SCC1] [float] NULL,
		[Throughput_SCC1] [float] NULL,
		[Throughput_MAX_SCC1] [real] NULL,
		[DataTransferred_SCC2] [int] NULL,
		[TransferTime_SCC2] [int] NULL,
		[Throughput_SCC2] [int] NULL,
		[Throughput_MAX_SCC2] [int] NULL,
		[DataTransferred_SCC3] [int] NULL,
		[TransferTime_SCC3] [int] NULL,
		[Throughput_SCC3] [int] NULL,
		[Throughput_MAX_SCC3] [int] NULL,
		[DataTransferred_SCC4] [int] NULL,
		[TransferTime_SCC4] [int] NULL,
		[Throughput_SCC4] [int] NULL,
		[Throughput_MAX_SCC4] [int] NULL,
		[DataTransferred_SCC5] [int] NULL,
		[TransferTime_SCC5] [int] NULL,
		[Throughput_SCC5] [int] NULL,
		[Throughput_MAX_SCC5] [int] NULL,
		[DataTransferred_SCC6] [int] NULL,
		[TransferTime_SCC6] [int] NULL,
		[Throughput_SCC6] [int] NULL,
		[Throughput_MAX_SCC6] [int] NULL,
		[DataTransferred_SCC7] [int] NULL,
		[TransferTime_SCC7] [int] NULL,
		[Throughput_SCC7] [int] NULL,
		[Throughput_MAX_SCC7] [int] NULL,
		[RLC_MAX] [float] NULL,
		[% LTE] [numeric](24, 12) NULL,
		[% WCDMA] [numeric](24, 12) NULL,
		[% GSM] [numeric](24, 12) NULL,
		[% F1 U2100] [numeric](24, 12) NULL,
		[% F2 U2100] [numeric](24, 12) NULL,
		[% F3 U2100] [numeric](24, 12) NULL,
		[% F1 U900] [numeric](24, 12) NULL,
		[% F2 U900] [numeric](24, 12) NULL,
		[% F1 L2600] [numeric](24, 12) NULL,
		[% F1 L2100] [numeric](24, 12) NULL,
		[% F2 L2100] [numeric](24, 12) NULL,
		[% F1 L1800] [numeric](24, 12) NULL,
		[% F2 L1800] [numeric](24, 12) NULL,
		[% F3 L1800] [numeric](24, 12) NULL,
		[% F1 L800] [numeric](24, 12) NULL,
		[% U2100] [numeric](24, 12) NULL,
		[% U900] [numeric](24, 12) NULL,
		[% LTE2600] [numeric](24, 12) NULL,
		[% LTE2100] [numeric](24, 12) NULL,
		[% LTE1800] [numeric](24, 12) NULL,
		[% LTE800] [numeric](24, 12) NULL,
		[DCS %] [numeric](24, 12) NULL,
		[GSM %] [numeric](24, 12) NULL,
		[EGSM %] [numeric](24, 12) NULL,
		[% LTE2600_SCC1] [numeric](24, 12) NULL,
		[% LTE1800_SCC1] [numeric](24, 12) NULL,
		[% LTE800_SCC1] [numeric](24, 12) NULL,
		[% LTE2600_SCC2] [int] NULL,
		[% LTE1800_SCC2] [int] NULL,
		[% LTE800_SCC2] [int] NULL,
		[% LTE2600_SCC3] [int] NULL,
		[% LTE1800_SCC3] [int] NULL,
		[% LTE800_SCC3] [int] NULL,
		[% LTE2600_SCC4] [int] NULL,
		[% LTE1800_SCC4] [int] NULL,
		[% LTE800_SCC4] [int] NULL,
		[% LTE2600_SCC5] [int] NULL,
		[% LTE1800_SCC5] [int] NULL,
		[% LTE800_SCC5] [int] NULL,
		[% LTE2600_SCC6] [int] NULL,
		[% LTE1800_SCC6] [int] NULL,
		[% LTE800_SCC6] [int] NULL,
		[% LTE2600_SCC7] [int] NULL,
		[% LTE1800_SCC7] [int] NULL,
		[% LTE800_SCC7] [int] NULL,
		[% QPSK 3G] [numeric](24, 12) NULL,
		[% 16QAM 3G] [numeric](24, 12) NULL,
		[% 64QAM 3G] [numeric](24, 12) NULL,
		[Num Codes] [numeric](38, 6) NULL,
		[Max Codes] [int] NULL,
		[% Dual Carrier] [numeric](24, 12) NULL,
		[Carriers] [int] NULL,
		[% QPSK 4G] [numeric](38, 6) NULL,
		[% 16QAM 4G] [numeric](38, 6) NULL,
		[% 64QAM 4G] [numeric](38, 6) NULL,
		[% QPSK 4G PCC] [numeric](38, 6) NULL,
		[% 16QAM 4G PCC] [numeric](38, 6) NULL,
		[% 64QAM 4G PCC] [numeric](38, 6) NULL,
		[% QPSK 4G SCC1] [numeric](38, 6) NULL,
		[% 16QAM 4G SCC1] [numeric](38, 6) NULL,
		[% 64QAM 4G SCC1] [numeric](38, 6) NULL,
		[% QPSK 4G SCC2] [int] NULL,
		[% 16AQM 4G SCC2] [int] NULL,
		[% 64QAM 4G SCC2] [int] NULL,
		[% QPSK 4G SCC3] [int] NULL,
		[% 16AQM 4G SCC3] [int] NULL,
		[% 64QAM 4G SCC3] [int] NULL,
		[% QPSK 4G SCC4] [int] NULL,
		[% 16AQM 4G SCC4] [int] NULL,
		[% 64QAM 4G SCC4] [int] NULL,
		[% QPSK 4G SCC5] [int] NULL,
		[% 16AQM 4G SCC5] [int] NULL,
		[% 64QAM 4G SCC5] [int] NULL,
		[% QPSK 4G SCC6] [int] NULL,
		[% 16AQM 4G SCC6] [int] NULL,
		[% 64QAM 4G SCC6] [int] NULL,
		[% QPSK 4G SCC7] [int] NULL,
		[% 16AQM 4G SCC7] [int] NULL,
		[% 64QAM 4G SCC7] [int] NULL,
		[10Mhz Bandwidth %] [numeric](24, 12) NULL,
		[15Mhz Bandwidth %] [numeric](24, 12) NULL,
		[20Mhz Bandwidth %] [numeric](24, 12) NULL,
		[10Mhz Bandwidth SCC1 %] [numeric](24, 12) NULL,
		[15Mhz Bandwidth SCC1 %] [numeric](24, 12) NULL,
		[20Mhz Bandwidth SCC1 %] [numeric](24, 12) NULL,
		[10Mhz Bandwidth SCC2 %] [int] NULL,
		[15Mhz Bandwidth SCC2 %] [int] NULL,
		[20Mhz Bandwidth SCC2 %] [int] NULL,
		[10Mhz Bandwidth SCC3 %] [int] NULL,
		[15Mhz Bandwidth SCC3 %] [int] NULL,
		[20Mhz Bandwidth SCC3 %] [int] NULL,
		[10Mhz Bandwidth SCC4 %] [int] NULL,
		[15Mhz Bandwidth SCC4 %] [int] NULL,
		[20Mhz Bandwidth SCC4 %] [int] NULL,
		[10Mhz Bandwidth SCC5 %] [int] NULL,
		[15Mhz Bandwidth SCC5 %] [int] NULL,
		[20Mhz Bandwidth SCC5 %] [int] NULL,
		[10Mhz Bandwidth SCC6 %] [int] NULL,
		[15Mhz Bandwidth SCC6 %] [int] NULL,
		[20Mhz Bandwidth SCC6 %] [int] NULL,
		[10Mhz Bandwidth SCC7 %] [int] NULL,
		[15Mhz Bandwidth SCC7 %] [int] NULL,
		[20Mhz Bandwidth SCC7 %] [int] NULL,
		[CQI 3G] [numeric](38, 6) NULL,	
		[% SCCH] [numeric](24, 12) NULL,
		[Procesos HARQ] [int] NULL,
		[BLER DSCH] [float] NULL,
		[DTX DSCH] [int] NULL,
		[ACKs] [int] NULL,
		[% NACKs] [numeric](24, 12) NULL,
		[Retrx DSCH] [float] NULL,
		[RETRX MAC] [varchar](1) NULL,
		[BLER RLC] [numeric](38, 17) NULL,
		[RLC Thput] [float] NULL,
		[RBs] [numeric](38, 12) NULL,
		[Max RBs] [numeric](13, 0) NULL,
		[Min RBs] [numeric](13, 0) NULL,
		[RBs When Allocated] [numeric](38, 12) NULL,
		[% TM Invalid] [numeric](24, 12) NULL,
		[% TM 1: Single Antenna Port 0 ] [numeric](24, 12) NULL,
		[% TM 2: TD Rank 1] [numeric](24, 12) NULL,
		[% TM 3: OL SM] [numeric](24, 12) NULL,
		[% TM 4: CL SM] [numeric](24, 12) NULL,
		[% TM 5: MU MIMO] [numeric](24, 12) NULL,
		[% TM 6: CL RANK1 PC] [numeric](24, 12) NULL,
		[% TM 7: Single Antenna Port 5] [numeric](24, 12) NULL,
		[% TM Unknown] [numeric](24, 12) NULL,
		[Shared channel use] [numeric](38, 6) NULL,
		[RBs PCC] [numeric](38, 12) NULL,
		[Max RBs PCC] [numeric](24, 0) NULL,
		[Min RBs PCC] [numeric](24, 0) NULL,
		[RBs When Allocated PCC] [numeric](38, 12) NULL,
		[% TM Invalid PCC] [numeric](24, 12) NULL,
		[% TM 1: Single Antenna Port 0 PCC] [numeric](24, 12) NULL,
		[% TM 2: TD Rank 1 PCC] [numeric](24, 12) NULL,
		[% TM 3: OL SM PCC] [numeric](24, 12) NULL,
		[% TM 4: CL SM PCC] [numeric](24, 12) NULL,
		[% TM 5: MU MIMO PCC] [numeric](24, 12) NULL,
		[% TM 6: CL RANK1 PC PCC] [numeric](24, 12) NULL,
		[% TM 7: Single Antenna Port 5 PCC] [numeric](24, 12) NULL,
		[% TM Unknown PCC] [numeric](24, 12) NULL,
		[CQI 4G PCC] [float] NULL,
		[Rank Indicator PCC] [int] NULL,
		[Shared channel use PCC] [numeric](38, 6) NULL,
		[RBs SCC1] [int] NULL,
		[Max RBs SCC1] [numeric](24, 0) NULL,
		[Min RBs SCC1] [numeric](24, 0) NULL,
		[RBs When Allocated SCC1] [numeric](38, 12) NULL,
		[% TM Invalid SCC1] [numeric](24, 12) NULL,
		[% TM 1: Single Antenna Port 0 SCC1] [numeric](24, 12) NULL,
		[% TM 2: TD Rank 1 SCC1] [numeric](24, 12) NULL,
		[% TM 3: OL SM SCC1] [numeric](24, 12) NULL,
		[% TM 4: CL SM SCC1] [numeric](24, 12) NULL,
		[% TM 5: MU MIMO SCC1] [numeric](24, 12) NULL,
		[% TM 6: CL RANK1 PC SCC1] [numeric](24, 12) NULL,
		[% TM 7: Single Antenna Port 5 SCC1] [numeric](24, 12) NULL,
		[% TM Unknown SCC1] [numeric](24, 12) NULL,
		[CQI 4G SCC1] [float] NULL,
		[Rank Indicator SCC1] [int] NULL,
		[Shared channel use SCC1] [numeric](38, 6) NULL,
		[RBs SCC2] [int] NULL,
		[Max RBs SCC2] [int] NULL,
		[Min RBs SCC2] [int] NULL,
		[RBs When Allocated SCC2] [int] NULL,
		[RBs SCC3] [int] NULL,
		[Max RBs SCC3] [int] NULL,
		[Min RBs SCC3] [int] NULL,
		[RBs When Allocated SCC3] [int] NULL,
		[RBs SCC4] [int] NULL,
		[Max RBs SCC4] [int] NULL,
		[Min RBs SCC4] [int] NULL,
		[RBs When Allocated SCC4] [int] NULL,
		[RBs SCC5] [int] NULL,
		[Max RBs SCC5] [int] NULL,
		[Min RBs SCC5] [int] NULL,
		[RBs When Allocated SCC5] [int] NULL,
		[RBs SCC6] [int] NULL,
		[Max RBs SCC6] [int] NULL,
		[Min RBs SCC6] [int] NULL,
		[RBs When Allocated SCC6] [int] NULL,
		[RBs SCC7] [int] NULL,
		[Max RBs SCC7] [int] NULL,
		[Min RBs SCC7] [int] NULL,
		[RBs When Allocated SCC7] [int] NULL,
		[% TM Invalid SCC2] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC2] [int] NULL,
		[% TM 2: TD Rank 1 SCC2] [int] NULL,
		[% TM 3: OL SM SCC2] [int] NULL,
		[% TM 4: CL SM SCC2] [int] NULL,
		[% TM 5: MU MIMO SCC2] [int] NULL,
		[% TM 6: CL RANK1 PC SCC2] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC2] [int] NULL,
		[% TM Unknown SCC2] [int] NULL,
		[% TM Invalid SCC3] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC3] [int] NULL,
		[% TM 2: TD Rank 1 SCC3] [int] NULL,
		[% TM 3: OL SM SCC3] [int] NULL,
		[% TM 4: CL SM SCC3] [int] NULL,
		[% TM 5: MU MIMO SCC3] [int] NULL,
		[% TM 6: CL RANK1 PC SCC3] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC3] [int] NULL,
		[% TM Unknown SCC3] [int] NULL,
		[% TM Invalid SCC4] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC4] [int] NULL,
		[% TM 2: TD Rank 1 SCC4] [int] NULL,
		[% TM 3: OL SM SCC4] [int] NULL,
		[% TM 4: CL SM SCC4] [int] NULL,
		[% TM 5: MU MIMO SCC4] [int] NULL,
		[% TM 6: CL RANK1 PC SCC4] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC4] [int] NULL,
		[% TM Unknown SCC4] [int] NULL,
		[% TM Invalid SCC5] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC5] [int] NULL,
		[% TM 2: TD Rank 1 SCC5] [int] NULL,
		[% TM 3: OL SM SCC5] [int] NULL,
		[% TM 4: CL SM SCC5] [int] NULL,
		[% TM 5: MU MIMO SCC5] [int] NULL,
		[% TM 6: CL RANK1 PC SCC5] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC5] [int] NULL,
		[% TM Unknown SCC5] [int] NULL,
		[% TM Invalid SCC6] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC6] [int] NULL,
		[% TM 2: TD Rank 1 SCC6] [int] NULL,
		[% TM 3: OL SM SCC6] [int] NULL,
		[% TM 4: CL SM SCC6] [int] NULL,
		[% TM 5: MU MIMO SCC6] [int] NULL,
		[% TM 6: CL RANK1 PC SCC6] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC6] [int] NULL,
		[% TM Unknown SCC6] [int] NULL,
		[% TM Invalid SCC7] [int] NULL,
		[% TM 1: Single Antenna Port 0 SCC7] [int] NULL,
		[% TM 2: TD Rank 1 SCC7] [int] NULL,
		[% TM 3: OL SM SCC7] [int] NULL,
		[% TM 4: CL SM SCC7] [int] NULL,
		[% TM 5: MU MIMO SCC7] [int] NULL,
		[% TM 6: CL RANK1 PC SCC7] [int] NULL,
		[% TM 7: Single Antenna Port 5 SCC7] [int] NULL,
		[% TM Unknown SCC7] [int] NULL,
		[CQI 4G SCC2] [int] NULL,
		[Rank Indicator SCC2] [int] NULL,
		[CQI 4G SCC3] [int] NULL,
		[Rank Indicator SCC3] [int] NULL,
		[CQI 4G SCC4] [int] NULL,
		[Rank Indicator SCC4] [int] NULL,
		[CQI 4G SCC5] [int] NULL,
		[Rank Indicator SCC5] [int] NULL,
		[CQI 4G SCC6] [int] NULL,
		[Rank Indicator SCC6] [int] NULL,
		[CQI 4G SCC7] [int] NULL,
		[Rank Indicator SCC7] [int] NULL,			
		[RxLev] [float] NULL,
		[RxQual] [float] NULL,
		[BCCH_Ini] [int] NULL,
		[BSIC_Ini] [int] NULL,
		[RxLev_Ini] [real] NULL,
		[RxQual_Ini] [real] NULL,
		[BCCH_Fin] [int] NULL,
		[BSIC_Fin] [int] NULL,
		[RxLev_Fin] [real] NULL,
		[RxQual_Fin] [real] NULL,
		[RxLev_min] [real] NULL,
		[RxQual_min] [real] NULL,
		[RSCP_avg] [float] NULL,
		[EcI0_avg] [float] NULL,
		[PSC_Ini] [int] NULL,
		[RSCP_Ini] [real] NULL,
		[EcIo_Ini] [real] NULL,
		[UARFCN_Ini] [int] NULL,
		[PSC_Fin] [int] NULL,
		[RSCP_Fin] [real] NULL,
		[EcIo_Fin] [real] NULL,
		[UARFCN_Fin] [int] NULL,
		[RSCP_min] [real] NULL,
		[EcIo_min] [real] NULL,
		[RSRP_avg] [float] NULL,
		[RSRQ_avg] [float] NULL,
		[SINR_avg] [float] NULL,
		[PCI_Ini] [int] NULL,
		[RSRP_Ini] [real] NULL,
		[RSRQ_Ini] [real] NULL,
		[SINR_Ini] [float] NULL,
		[EARFCN_Ini] [int] NULL,
		[PCI_Fin] [int] NULL,
		[RSRP_Fin] [real] NULL,
		[RSRQ_Fin] [real] NULL,
		[SINR_Fin] [float] NULL,
		[EARFCN_Fin] [int] NULL,
		[CellId_Ini] [int] NULL,
		[LAC/TAC_Ini] [int] NULL,
		[RNC_Ini] [int] NULL,
		[CellId_Fin] [int] NULL,
		[LAC/TAC_Fin] [int] NULL,
		[RNC_Fin] [int] NULL,
		[Longitud Inicial] [float] NULL,
		[Latitud Inicial] [float] NULL,
		[Longitud Final] [float] NULL,
		[Latitud Final] [float] NULL,

		-- @DGP: usa de CA
		[Blocks_NoCA] [numeric](13, 0) NULL,
		[Blocks_CA] [numeric](13, 0) NULL,
		[% CA] [numeric](38, 12) NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[ThputApp_nu] [float] NULL,
		[DataTransferred_nu] [float] NULL,
		[SessionTime_nu] [float] NULL,
		[TransferTime_nu] [float] NULL,
		[IPAccessTime_sec_nu] [float] NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[Tech_Ini] [varchar](50) NULL,
		[Tech_Fin] [varchar](50) NULL,
		-- @DGP: Uso de Dual Carrier desglosado por banda
		[% Dual Carrier U2100] [numeric](24, 12) NULL,
		[% Dual Carrier U900] [numeric](24, 12) NULL,
		-- @DGP: UL interferences
		[UL_Interference] [real] null,

		-- @ERC: KPIID de P3
		[SessionTime] [float] NULL,

		--@DGP: KPI EXTRAS CEM
		[PDP_Activate_Ratio] [float] NULL,
		[Paging_Success_Ratio] [float] NULL,
		[EARFCN_N1] [int] NULL,
		[PCI_N1] [int] NULL,
		[RSRP_N1] [real] NULL,
		[RSRQ_N1] [real] NULL,
		[num_HO_S1X2] [int] NULL,
		[duration_S1X2_avg] [float] NULL,
		[S1X2HO_SR] [float] NULL,
		[Max_Window_Size] [int] NULL,

		--@CAC: CQI por tecnologia
		[CQI UMTS900] [numeric](38, 6) NULL,
		[CQI UMTS2100] [numeric](38, 6) NULL,		
		[CQI LTE2600] [float] NULL,
		[CQI LTE1800] [float] NULL,
		[CQI LTE800] [float] NULL,
		[CQI LTE2100] [float] NULL,
		[IMSI] [varchar] (50) NULL
	)
end

if (select name from sys.all_objects where name='Lcc_Data_HTTPTransfer_UL' and type='U') is null
begin
	CREATE TABLE [dbo].[Lcc_Data_HTTPTransfer_UL](
		[MTU] [char](10) NULL,
		[IMEI] [varchar](50) NULL,
		[CollectionName] [varchar](100) NULL,
		[MCC] [varchar](3) NULL,
		[MNC] [varchar](2) NULL,
		[startDate] [varchar](50) NULL,
		[startTime] [datetime2](3) NULL,
		[endTime] [datetime2](3) NULL,
		[SessionId] [bigint] NULL,
		[FileId] [bigint] NOT NULL,
		[TestId] [bigint] NOT NULL,
		[typeoftest] [varchar](50) NULL,
		[direction] [varchar](20) NULL,
		[info] [varchar](50) NULL,
		[TestType] [varchar](5) NULL,
		[ServiceType] [varchar](1) NULL,
		[IP Access Time (ms)] [int] NULL,
		[DataTransferred] [float] NULL,
		[TransferTime] [float] NULL,
		[ErrorCause] [varchar](1024) NULL,
		[ErrorType] [varchar](1024) NULL,
		[Throughput] [float] NULL,
		[Throughput_MAX] [real] NULL,
		[RLC_MAX] [float] NULL,
		[% LTE] [numeric](24, 12) NULL,
		[% WCDMA] [numeric](24, 12) NULL,
		[% GSM] [numeric](24, 12) NULL,
		[% F1 U2100] [numeric](24, 12) NULL,
		[% F2 U2100] [numeric](24, 12) NULL,
		[% F3 U2100] [numeric](24, 12) NULL,
		[% F1 U900] [numeric](24, 12) NULL,
		[% F2 U900] [numeric](24, 12) NULL,
		[% F1 L2600] [numeric](24, 12) NULL,
		[% F1 L2100] [numeric](24, 12) NULL,
		[% F2 L2100] [numeric](24, 12) NULL,
		[% F1 L1800] [numeric](24, 12) NULL,
		[% F2 L1800] [numeric](24, 12) NULL,
		[% F3 L1800] [numeric](24, 12) NULL,
		[% F1 L800] [numeric](24, 12) NULL,
		[% U2100] [numeric](24, 12) NULL,
		[% U900] [numeric](24, 12) NULL,
		[% LTE2600] [numeric](24, 12) NULL,
		[% LTE2100] [numeric](24, 12) NULL,
		[% LTE1800] [numeric](24, 12) NULL,
		[% LTE800] [numeric](24, 12) NULL,
		[DCS %] [numeric](24, 12) NULL,
		[GSM %] [numeric](24, 12) NULL,
		[EGSM %] [numeric](24, 12) NULL,
		[% SF22] [numeric](28, 12) NULL,
		[% SF22andSF42] [numeric](28, 12) NULL,
		[% SF4] [numeric](28, 12) NULL,
		[% SF42] [numeric](28, 12) NULL,
		[HSUPA 2.0] [varchar](1) NULL,
		[% TTI 2ms] [int] NULL,
		[Carriers] [int] NULL,
		[% Dual Carrier] [numeric](24, 12) NULL,
		[% BPSK 4G] [numeric](38, 6) NULL,
		[% QPSK 4G] [numeric](38, 6) NULL,
		[% 16QAM 4G] [numeric](38, 6) NULL,
		[10Mhz Bandwidth %] [numeric](24, 12) NULL,
		[15Mhz Bandwidth %] [numeric](24, 12) NULL,
		[20Mhz Bandwidth %] [numeric](24, 12) NULL,
		[HappyRate] [float] NULL,
		[Happy Rate MAX] [real] NULL,
		[Serving Grant] [float] NULL,
		[DTX] [float] NULL,
		[avg TBs size] [int] NULL,
		[% SHO] [numeric](13, 1) NULL,
		[ReTrx PDU] [varchar](1) NULL,
		[RBs] [numeric](38, 12) NULL,
		[Max RBs] [numeric](13, 0) NULL,
		[Min RBs] [numeric](13, 0) NULL,
		[RBs When Allocated] [numeric](38, 12) NULL,
		[CQI 4G] [float] NULL,
		[Rank Indicator] [int] NULL,
		[Shared channel use] [numeric](38, 6) NULL,
		[% TM Invalid] [numeric](24, 12) NULL,
		[% TM 1: Single Antenna Port 0] [numeric](24, 12) NULL,
		[% TM 2: TD Rank 1] [numeric](24, 12) NULL,
		[% TM 3: OL SM] [numeric](24, 12) NULL,
		[% TM 4: CL SM] [numeric](24, 12) NULL,
		[% TM 5: MU MIMO] [numeric](24, 12) NULL,
		[% TM 6: CL RANK1 PC] [numeric](24, 12) NULL,
		[% TM 7: Single Antenna Port 5] [numeric](24, 12) NULL,
		[% TM 8] [numeric](24, 12) NULL,
		[% TM 9] [numeric](24, 12) NULL,
		[% TM Unknown] [numeric](24, 12) NULL,
		[RxLev] [float] NULL,
		[RxQual] [float] NULL,
		[BCCH_Ini] [int] NULL,
		[BSIC_Ini] [int] NULL,
		[RxLev_Ini] [real] NULL,
		[RxQual_Ini] [real] NULL,
		[BCCH_Fin] [int] NULL,
		[BSIC_Fin] [int] NULL,
		[RxLev_Fin] [real] NULL,
		[RxQual_Fin] [real] NULL,
		[RxLev_min] [real] NULL,
		[RxQual_min] [real] NULL,
		[RSCP_avg] [float] NULL,
		[EcI0_avg] [float] NULL,
		[PSC_Ini] [int] NULL,
		[RSCP_Ini] [real] NULL,
		[EcIo_Ini] [real] NULL,
		[UARFCN_Ini] [int] NULL,
		[PSC_Fin] [int] NULL,
		[RSCP_Fin] [real] NULL,
		[EcIo_Fin] [real] NULL,
		[UARFCN_Fin] [int] NULL,
		[RSCP_min] [real] NULL,
		[EcIo_min] [real] NULL,
		[RSRP_avg] [float] NULL,
		[RSRQ_avg] [float] NULL,
		[SINR_avg] [float] NULL,
		[PCI_Ini] [int] NULL,
		[RSRP_Ini] [real] NULL,
		[RSRQ_Ini] [real] NULL,
		[SINR_Ini] [float] NULL,
		[EARFCN_Ini] [int] NULL,
		[PCI_Fin] [int] NULL,
		[RSRP_Fin] [real] NULL,
		[RSRQ_Fin] [real] NULL,
		[SINR_Fin] [float] NULL,
		[EARFCN_Fin] [int] NULL,
		[CellId_Ini] [int] NULL,
		[LAC/TAC_Ini] [int] NULL,
		[RNC_Ini] [int] NULL,
		[CellId_Fin] [int] NULL,
		[LAC/TAC_Fin] [int] NULL,
		[RNC_Fin] [int] NULL,
		[Longitud Inicial] [float] NULL,
		[Latitud Inicial] [float] NULL,
		[Longitud Final] [float] NULL,
		[Latitud Final] [float] NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[ThputApp_nu] [float] NULL,
		[DataTransferred_nu] [float] NULL,
		[SessionTime_nu] [float] NULL,
		[TransferTime_nu] [float] NULL,
		[IPAccessTime_sec_nu] [float] NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[Tech_Ini] [varchar](50) NULL,
		[Tech_Fin] [varchar](50) NULL,
		-- @DGP: Uso de Dual Carrier desglosado por banda
		[% Dual Carrier U2100] [numeric](24, 12) NULL,
		[% Dual Carrier U900] [numeric](24, 12) NULL,
		-- @DGP: UL interferences
		[UL_Interference] [real] null,
		
		-- @ERC: KPIID de P3
		[SessionTime] [float] NULL,

		--@DGP: KPI EXTRAS CEM
		[PDP_Activate_Ratio] [float] NULL,
		[Paging_Success_Ratio] [float] NULL,
		[EARFCN_N1] [int] NULL,
		[PCI_N1] [int] NULL,
		[RSRP_N1] [real] NULL,
		[RSRQ_N1] [real] NULL,
		[num_HO_S1X2] [int] NULL,
		[duration_S1X2_avg] [float] NULL,
		[S1X2HO_SR] [float] NULL,
		[Max_Window_Size] [int] NULL,

		--@CAC: CQI por tecnologia		
		[CQI LTE2600] [float] NULL,
		[CQI LTE1800] [float] NULL,
		[CQI LTE800] [float] NULL,
		[CQI LTE2100] [float] NULL,
		[IMSI] [varchar] (50) NULL

	) 
end

if (select name from sys.all_objects where name='Lcc_Data_HTTPBrowser' and type='U') is null
begin
	CREATE TABLE [dbo].[Lcc_Data_HTTPBrowser](
		[MTU] [char](10) NULL,
		[IMEI] [varchar](50) NULL,
		[CollectionName] [varchar](100) NULL,
		[MCC] [varchar](3) NULL,
		[MNC] [varchar](2) NULL,
		[startDate] [varchar](50) NULL,
		[startTime] [datetime2](3) NULL,
		[endTime] [datetime2](3) NULL,
		[SessionId] [bigint] NULL,
		[FileId] [bigint] NOT NULL,
		[TestId] [bigint] NOT NULL,
		[typeoftest] [varchar](50) NULL,
		[direction] [varchar](20) NULL,
		[info] [varchar](50) NULL,
		[TestType] [varchar](23) NULL,
		[ServiceType] [varchar](1) NULL,
		[DataTransferred] [int] NULL,
		[ErrorCause] [varchar](1031) NULL,
		[ErrorType] [varchar](13) NULL,
		[Throughput] [numeric](14, 3) NULL,
		[Throughput_MAX] [real] NULL,	
		[DataTransferred_PCC] [numeric](38, 1) NULL,
		[TransferTime_PCC] [numeric](38, 6) NULL,
		[Throughput_PCC] [float] NULL,
		[Throughput_MAX_PCC] [real] NULL,
		[DataTransferred_SCC1] [numeric](38, 1) NULL,
		[TransferTime_SCC1] [numeric](38, 6) NULL,
		[Throughput_SCC1] [float] NULL,
		[Throughput_MAX_SCC1] [real] NULL,
		[IP Service Setup Time (s)] [numeric](17, 6) NULL,
		[DNS Resolution (s)] [numeric](17, 6) NULL,
		[Transfer Time (s)] [numeric](25, 12) NULL,
		[Session Time (s)] [numeric](24, 12) NULL,
		[% LTE] [numeric](24, 12) NULL,
		[% WCDMA] [numeric](24, 12) NULL,
		[% GSM] [numeric](24, 12) NULL,
		[% F1 U2100] [numeric](24, 12) NULL,
		[% F2 U2100] [numeric](24, 12) NULL,
		[% F3 U2100] [numeric](24, 12) NULL,
		[% F1 U900] [numeric](24, 12) NULL,
		[% F2 U900] [numeric](24, 12) NULL,
		[% F1 L2600] [numeric](24, 12) NULL,
		[% F1 L2100] [numeric](24, 12) NULL,
		[% F2 L2100] [numeric](24, 12) NULL,
		[% F1 L1800] [numeric](24, 12) NULL,
		[% F2 L1800] [numeric](24, 12) NULL,
		[% F3 L1800] [numeric](24, 12) NULL,
		[% F1 L800] [numeric](24, 12) NULL,
		[% U2100] [numeric](24, 12) NULL,
		[% U900] [numeric](24, 12) NULL,
		[% LTE2600] [numeric](24, 12) NULL,
		[% LTE2100] [numeric](24, 12) NULL,
		[% LTE1800] [numeric](24, 12) NULL,
		[% LTE800] [numeric](24, 12) NULL,
		[DCS %] [numeric](24, 12) NULL,
		[GSM %] [numeric](24, 12) NULL,
		[EGSM %] [numeric](24, 12) NULL,
		[% LTE2600_SCC1] [numeric](24, 12) NULL,
		[% LTE1800_SCC1] [numeric](24, 12) NULL,
		[% LTE800_SCC1] [numeric](24, 12) NULL,
		[% LTE2600_SCC2] [int] NULL,
		[% LTE1800_SCC2] [int] NULL,
		[% LTE800_SCC2] [int] NULL,
		[% LTE2600_SCC3] [int] NULL,
		[% LTE1800_SCC3] [int] NULL,
		[% LTE800_SCC3] [int] NULL,
		[% LTE2600_SCC4] [int] NULL,
		[% LTE1800_SCC4] [int] NULL,
		[% LTE800_SCC4] [int] NULL,
		[% LTE2600_SCC5] [int] NULL,
		[% LTE1800_SCC5] [int] NULL,
		[% LTE800_SCC5] [int] NULL,
		[% LTE2600_SCC6] [int] NULL,
		[% LTE1800_SCC6] [int] NULL,
		[% LTE800_SCC6] [int] NULL,
		[% LTE2600_SCC7] [int] NULL,
		[% LTE1800_SCC7] [int] NULL,
		[% LTE800_SCC7] [int] NULL,
		[Carriers] [int] NULL,
		[% Dual Carrier] [numeric](24, 12) NULL,
		[RxLev] [float] NULL,
		[RxQual] [float] NULL,
		[BCCH_Ini] [int] NULL,
		[BSIC_Ini] [int] NULL,
		[RxLev_Ini] [real] NULL,
		[RxQual_Ini] [real] NULL,
		[BCCH_Fin] [int] NULL,
		[BSIC_Fin] [int] NULL,
		[RxLev_Fin] [real] NULL,
		[RxQual_Fin] [real] NULL,
		[RxLev_min] [real] NULL,
		[RxQual_min] [real] NULL,
		[RSCP_avg] [float] NULL,
		[EcI0_avg] [float] NULL,
		[PSC_Ini] [int] NULL,
		[RSCP_Ini] [real] NULL,
		[EcIo_Ini] [real] NULL,
		[UARFCN_Ini] [int] NULL,
		[PSC_Fin] [int] NULL,
		[RSCP_Fin] [real] NULL,
		[EcIo_Fin] [real] NULL,
		[UARFCN_Fin] [int] NULL,
		[RSCP_min] [real] NULL,
		[EcIo_min] [real] NULL,
		[RSRP_avg] [float] NULL,
		[RSRQ_avg] [float] NULL,
		[SINR_avg] [float] NULL,
		[PCI_Ini] [int] NULL,
		[RSRP_Ini] [real] NULL,
		[RSRQ_Ini] [real] NULL,
		[SINR_Ini] [float] NULL,
		[EARFCN_Ini] [int] NULL,
		[PCI_Fin] [int] NULL,
		[RSRP_Fin] [real] NULL,
		[RSRQ_Fin] [real] NULL,
		[SINR_Fin] [float] NULL,
		[EARFCN_Fin] [int] NULL,
		[CellId_Ini] [int] NULL,
		[LAC/TAC_Ini] [int] NULL,
		[RNC_Ini] [int] NULL,
		[CellId_Fin] [int] NULL,
		[LAC/TAC_Fin] [int] NULL,
		[RNC_Fin] [int] NULL,
		[Longitud Inicial] [float] NULL,
		[Latitud Inicial] [float] NULL,
		[Longitud Final] [float] NULL,
		[Latitud Final] [float] NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[DataTransferred_nu] [numeric](14, 3) NULL, 		
		[ThputApp_nu] [numeric](14, 3) NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[IP_AccessTime_sec_nu] [numeric](17, 6) NULL,
		[Transfer_Time_sec_nu] [numeric](25, 12) NULL,
		[Session_Time_sec_nu] [numeric](24, 12) NULL,
		[DNSTime_nu] [numeric](17, 6) NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[Tech_Ini] [varchar](50) NULL,
		[Tech_Fin] [varchar](50) NULL,
		-- @DGP: Uso de Dual Carrier desglosado por banda
		[% Dual Carrier U2100] [numeric](24, 12) NULL,
		[% Dual Carrier U900] [numeric](24, 12) NULL,
		-- @DGP: UL interferences
		[UL_Interference] [real] null,

		--@DGP: KPI EXTRAS CEM
		[PDP_Activate_Ratio] [float] NULL,
		[Paging_Success_Ratio] [float] NULL,
		[EARFCN_N1] [int] NULL,
		[PCI_N1] [int] NULL,
		[RSRP_N1] [real] NULL,
		[RSRQ_N1] [real] NULL,
		[num_HO_S1X2] [int] NULL,
		[duration_S1X2_avg] [float] NULL,
		[S1X2HO_SR] [float] NULL,
		[Max_Window_Size] [int] NULL,
		[IMSI] [varchar] (50) NULL
	)
end

if (select name from sys.all_objects where name='Lcc_Data_YOUTUBE' and type='U') is null
begin
	CREATE TABLE [dbo].[Lcc_Data_YOUTUBE](
		[MTU] [char](10) NULL,
		[IMEI] [varchar](50) NULL,
		[CollectionName] [varchar](100) NULL,
		[MCC] [varchar](3) NULL,
		[MNC] [varchar](2) NULL,
		[startDate] [varchar](50) NULL,
		[startTime] [datetime2](3) NULL,
		[endTime] [datetime2](3) NULL,
		[SessionId] [bigint] NULL,
		[FileId] [bigint] NOT NULL,
		[TestId] [bigint] NOT NULL,
		[typeoftest] [varchar](50) NULL,
		[direction] [varchar](20) NULL,
		[info] [varchar](50) NULL,
		[testname] [varchar](50) NULL,
		[Video Resolution] [varchar](50) NULL,
		[Fails] [varchar](10) NULL,
		[Cause] [varchar](50) NULL,
		[Block Time] [datetime2](3) NULL,
		[Time To First Image [s]]] [numeric](17, 6) NULL,
		[Num. Interruptions] [int] NULL,
		[Video Freezing Impairment] [varchar](12) NULL,
		[Accumulated Video Freezing Duration [s]]] [int] NULL,
		[Average Video Freezing Duration [s]]] [int] NULL,
		[Maximum Video Freezing Duration [s]]] [int] NULL,
		[End Status] [varchar](17) NULL,
		[Succeesful_Video_Download] [varchar](17) NULL,
		[% LTE] [numeric](24, 12) NULL,
		[% WCDMA] [numeric](24, 12) NULL,
		[% GSM] [numeric](24, 12) NULL,
		[% F1 U2100] [numeric](24, 12) NULL,
		[% F2 U2100] [numeric](24, 12) NULL,
		[% F3 U2100] [numeric](24, 12) NULL,
		[% F1 U900] [numeric](24, 12) NULL,
		[% F2 U900] [numeric](24, 12) NULL,
		[% F1 L2600] [numeric](24, 12) NULL,
		[% F1 L2100] [numeric](24, 12) NULL,
		[% F2 L2100] [numeric](24, 12) NULL,
		[% F1 L1800] [numeric](24, 12) NULL,
		[% F2 L1800] [numeric](24, 12) NULL,
		[% F3 L1800] [numeric](24, 12) NULL,
		[% F1 L800] [numeric](24, 12) NULL,
		[% U2100] [numeric](24, 12) NULL,
		[% U900] [numeric](24, 12) NULL,
		[% LTE2600] [numeric](24, 12) NULL,
		[% LTE2100] [numeric](24, 12) NULL,
		[% LTE1800] [numeric](24, 12) NULL,
		[% LTE800] [numeric](24, 12) NULL,
		[DCS %] [numeric](24, 12) NULL,
		[GSM %] [numeric](24, 12) NULL,
		[EGSM %] [numeric](24, 12) NULL,
		[% LTE2600_SCC1] [numeric](24, 12) NULL,
		[% LTE1800_SCC1] [numeric](24, 12) NULL,
		[% LTE800_SCC1] [numeric](24, 12)  NULL,
		[% LTE2600_SCC2] [int] NULL,
		[% LTE1800_SCC2] [int] NULL,
		[% LTE800_SCC2] [int] NULL,
		[% LTE2600_SCC3] [int] NULL,
		[% LTE1800_SCC3] [int] NULL,
		[% LTE800_SCC3] [int] NULL,
		[% LTE2600_SCC4] [int] NULL,
		[% LTE1800_SCC4] [int] NULL,
		[% LTE800_SCC4] [int] NULL,
		[% LTE2600_SCC5] [int] NULL,
		[% LTE1800_SCC5] [int] NULL,
		[% LTE800_SCC5] [int] NULL,
		[% LTE2600_SCC6] [int] NULL,
		[% LTE1800_SCC6] [int] NULL,
		[% LTE800_SCC6] [int] NULL,
		[% LTE2600_SCC7] [int] NULL,
		[% LTE1800_SCC7] [int] NULL,
		[% LTE800_SCC7] [int] NULL,
		[RxLev] [float] NULL,
		[RxQual] [float] NULL,
		[BCCH_Ini] [int] NULL,
		[BSIC_Ini] [int] NULL,
		[RxLev_Ini] [real] NULL,
		[RxQual_Ini] [real] NULL,
		[BCCH_Fin] [int] NULL,
		[BSIC_Fin] [int] NULL,
		[RxLev_Fin] [real] NULL,
		[RxQual_Fin] [real] NULL,
		[RxLev_min] [real] NULL,
		[RxQual_min] [real] NULL,
		[RSCP_avg] [float] NULL,
		[EcI0_avg] [float] NULL,
		[PSC_Ini] [int] NULL,
		[RSCP_Ini] [real] NULL,
		[EcIo_Ini] [real] NULL,
		[UARFCN_Ini] [int] NULL,
		[PSC_Fin] [int] NULL,
		[RSCP_Fin] [real] NULL,
		[EcIo_Fin] [real] NULL,
		[UARFCN_Fin] [int] NULL,
		[RSCP_min] [real] NULL,
		[EcIo_min] [real] NULL,
		[RSRP_avg] [float] NULL,
		[RSRQ_avg] [float] NULL,
		[SINR_avg] [float] NULL,
		[PCI_Ini] [int] NULL,
		[RSRP_Ini] [real] NULL,
		[RSRQ_Ini] [real] NULL,
		[SINR_Ini] [float] NULL,
		[EARFCN_Ini] [int] NULL,
		[PCI_Fin] [int] NULL,
		[RSRP_Fin] [real] NULL,
		[RSRQ_Fin] [real] NULL,
		[SINR_Fin] [float] NULL,
		[EARFCN_Fin] [int] NULL,
		[CellId_Ini] [int] NULL,
		[LAC/TAC_Ini] [int] NULL,
		[RNC_Ini] [int] NULL,
		[CellId_Fin] [int] NULL,
		[LAC/TAC_Fin] [int] NULL,
		[RNC_Fin] [int] NULL,
		[Longitud Inicial] [float] NULL,
		[Latitud Inicial] [float] NULL,
		[Longitud Final] [float] NULL,
		[Latitud Final] [float] NULL,
		-- @ERC: Valores sin updates para montar los libros externos de errores de datos
		[Tech_Ini] [varchar](50) NULL,
		[Tech_Fin] [varchar](50) NULL,

		--@DGP: KPI EXTRAS CEM
		[PDP_Activate_Ratio] [float] NULL,
		[Paging_Success_Ratio] [float] NULL,
		[EARFCN_N1] [int] NULL,
		[PCI_N1] [int] NULL,
		[RSRP_N1] [real] NULL,
		[RSRQ_N1] [real] NULL,
		[num_HO_S1X2] [int] NULL,
		[duration_S1X2_avg] [float] NULL,
		[S1X2HO_SR] [float] NULL,
		[Max_Window_Size] [int] NULL,
		[Buffering_Time_Sec] [float] NULL,
		[Video_MOS] [Float] NULL,
		[IMSI] [varchar] (50) NULL
		)
end

if (select name from sys.all_objects where name='Lcc_Data_Latencias' and type='U') is null
begin
	CREATE TABLE [dbo].[Lcc_Data_Latencias](
		[MTU] [char](10) NULL,
		[IMEI] [varchar](50) NULL,
		[CollectionName] [varchar](100) NULL,
		[MCC] [varchar](3) NULL,
		[MNC] [varchar](2) NULL,
		[startDate] [varchar](50) NULL,
		[startTime] [datetime2](3) NULL,
		[endTime] [datetime2](3) NULL,
		[SessionId] [bigint] NULL,
		[FileId] [bigint] NOT NULL,
		[TestId] [bigint] NOT NULL,
		[typeoftest] [varchar](50) NULL,
		[direction] [varchar](20) NULL,
		[info] [varchar](50) NULL,
		[RTT] [int] NULL,
		[% LTE] [numeric](24, 12) NULL,
		[% WCDMA] [numeric](24, 12) NULL,
		[% GSM] [numeric](24, 12) NULL,
		[% F1 U2100] [numeric](24, 12) NULL,
		[% F2 U2100] [numeric](24, 12) NULL,
		[% F3 U2100] [numeric](24, 12) NULL,
		[% F1 U900] [numeric](24, 12) NULL,
		[% F2 U900] [numeric](24, 12) NULL,
		[% F1 L2600] [numeric](24, 12) NULL,
		[% F1 L2100] [numeric](24, 12) NULL,
		[% F2 L2100] [numeric](24, 12) NULL,
		[% F1 L1800] [numeric](24, 12) NULL,
		[% F2 L1800] [numeric](24, 12) NULL,
		[% F3 L1800] [numeric](24, 12) NULL,
		[% F1 L800] [numeric](24, 12) NULL,
		[% U2100] [numeric](24, 12) NULL,
		[% U900] [numeric](24, 12) NULL,
		[% LTE2600] [numeric](24, 12) NULL,
		[% LTE2100] [numeric](24, 12) NULL,
		[% LTE1800] [numeric](24, 12) NULL,
		[% LTE800] [numeric](24, 12) NULL,
		[DCS %] [numeric](24, 12) NULL,
		[GSM %] [numeric](24, 12) NULL,
		[EGSM %] [numeric](24, 12) NULL,
		[% LTE2600_SCC1] [numeric](24, 12) NULL,
		[% LTE1800_SCC1] [numeric](24, 12) NULL,
		[% LTE800_SCC1] [numeric](24, 12) NULL,
		[% LTE2600_SCC2] [int] NULL,
		[% LTE1800_SCC2] [int] NULL,
		[% LTE800_SCC2] [int] NULL,
		[% LTE2600_SCC3] [int] NULL,
		[% LTE1800_SCC3] [int] NULL,
		[% LTE800_SCC3] [int] NULL,
		[% LTE2600_SCC4] [int] NULL,
		[% LTE1800_SCC4] [int] NULL,
		[% LTE800_SCC4] [int] NULL,
		[% LTE2600_SCC5] [int] NULL,
		[% LTE1800_SCC5] [int] NULL,
		[% LTE800_SCC5] [int] NULL,
		[% LTE2600_SCC6] [int] NULL,
		[% LTE1800_SCC6] [int] NULL,
		[% LTE800_SCC6] [int] NULL,
		[% LTE2600_SCC7] [int] NULL,
		[% LTE1800_SCC7] [int] NULL,
		[% LTE800_SCC7] [int] NULL,
		[Longitud Inicial] [float] NULL,
		[Latitud Inicial] [float] NULL,
		[Longitud Final] [float] NULL,
		[Latitud Final] [float] NULL,

		--@DGP: KPI EXTRAS CEM
		[PDP_Activate_Ratio] [float] NULL,
		[Paging_Success_Ratio] [float] NULL,
		[EARFCN_N1] [int] NULL,
		[PCI_N1] [int] NULL,
		[RSRP_N1] [real] NULL,
		[RSRQ_N1] [real] NULL,
		[num_HO_S1X2] [int] NULL,
		[duration_S1X2_avg] [float] NULL,
		[S1X2HO_SR] [float] NULL,
		[IMSI] [varchar] (50) NULL
		)
end



--********************************************************************************************************************
--****************************************** FILTRADOS POR TESTID de INTERES *****************************************
--********************************************************************************************************************

-- Se cogen el ultimo testid de cada tabla 		
select MAX(testid) as maxTestID into #maxTestID from Lcc_Data_HTTPTransfer_DL union all
select MAX(testid) as maxTestID from Lcc_Data_HTTPTransfer_UL union all
select MAX(testid) as maxTestID from Lcc_Data_HTTPBrowser union all
select MAX(testid) as maxTestID from Lcc_Data_YOUTUBE union all
select MAX(testid) as maxTestID from Lcc_Data_Latencias 


-- Se calculara la info general (tablas intermedias) a partir del testid minimo de la tabla anterior (el primero de de los ultimos)
-- Luego cada tabla final cogera el que le corresponda
declare @maxTestid as int=(select min(ISNULL(maxTestID,0)) from #maxTestID)

declare @maxTestid_DL as int=(select ISNULL(MAX(testid),0) from Lcc_Data_HTTPTransfer_DL)
declare @maxTestid_UL as int=(select ISNULL(MAX(testid),0) from Lcc_Data_HTTPTransfer_UL)
declare @maxTestid_BR as int=(select ISNULL(MAX(testid),0) from Lcc_Data_HTTPBrowser)
declare @maxTestid_YTB as int=(select ISNULL(MAX(testid),0) from Lcc_Data_YOUTUBE)
declare @maxTestid_LAT as int=(select ISNULL(MAX(testid),0) from Lcc_Data_Latencias)

declare @maxSessionid as int=(select ISNULL(min(SessionId),0) from testinfo where testid = @maxTestid)

--La mínima session (si es null el testid lo pasamos a 0 para que se quede con este como mínimo)
declare @minSessionid as int=(select ISNULL(min(SessionId),0) from testinfo where testid = (select min(ISNULL(maxTestID,0)) from #maxTestID))


select 'Calculated SERVING CELL INFO from testid='+CONVERT(varchar(256),@maxTestid)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info
select 'Calculated PHYSICAL INFO from testid='+CONVERT(varchar(256),@maxTestid)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info

select 'Updated Lcc_Data_HTTPTransfer_DL from testid='+CONVERT(varchar(256),@maxTestid_DL)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info
select 'Updated Lcc_Data_HTTPTransfer_UL from testid='+CONVERT(varchar(256),@maxTestid_UL)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info
select 'Updated Lcc_Data_HTTPBrowser from testid='+CONVERT(varchar(256),@maxTestid_BR)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info
select 'Updated Lcc_Data_YOUTUBE from testid='+CONVERT(varchar(256),@maxTestid_YTB)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info
select 'Updated Lcc_Data_Latencias from testid='+CONVERT(varchar(256),@maxTestid_LAT)+' to testid='+CONVERT(varchar(256),(select max(TestId) from TestInfo)) info



--***************************************************************************************************************************
--************************************************ INICIO TABLAS INTERMEDIAS ************************************************
--***************************************************************************************************************************
select 'INICIO TABLAS INTERMEDIAS' info

------------------------------ (1) SERVING CELL  4G/3G/2G	------------------------------
--select 'Se crean las tablas intermedias: (1) SERVING CELL  4G/3G/2G' info
--------------
 --GSM/WCDMA/LTE Radio AVG (Radio Values)		
exec sp_lcc_dropifexists '_TECH_RADIO_AVG_Data'			
select  
	t.sessionid, t.testid, 
	
	-- Para la PCC:
	log10(avg(power(10.0E0,(case when t.band in ('GSM','DCS', 'EGSM') then 1.0 * t.signal end)/10.0E0)))*10 as RxLev,
	log10(avg(power(10.0E0,(case when t.band in ('GSM','DCS', 'EGSM') then 1.0 * t.quality end)/10.0E0)))*10 as RxQual,
	MIN(case when t.band in ('GSM','DCS', 'EGSM') then t.signal end) as RxLev_min,		
	MIN(case when t.band in ('GSM','DCS', 'EGSM') then t.quality end) as RxQual_min,		
	MAX(case when t.band in ('GSM','DCS', 'EGSM') then t.signal end) as RxLev_max,		
	MAX(case when t.band in ('GSM','DCS', 'EGSM') then t.quality end) as RxQual_max,		
	
	log10(avg(power(10.0E0,(case when t.band  like '%UMTS%' then 1.0 * t.signal end)/10.0E0)))*10 as RSCP,
	log10(avg(power(10.0E0,(case when t.band  like '%UMTS%' then 1.0 * t.quality end)/10.0E0)))*10 as EcIo,
	MIN(case when t.band like '%UMTS%' then t.signal end) as RSCP_min,		
	MIN(case when t.band like '%UMTS%' then t.quality end) as EcIo_min,		
	MAX(case when t.band like '%UMTS%' then t.signal end) as RSCP_max,		
	MAX(case when t.band like '%UMTS%' then t.quality end) as EcIo_max,	
	
	log10(avg(power(10.0E0,(case when t.band  like '%LTE%' then 1.0 * t.signal end)/10.0E0)))*10 as RSRP,
	log10(avg(power(10.0E0,(case when t.band  like '%LTE%' then 1.0 * t.quality end)/10.0E0)))*10 as RSRQ,
	log10(AVG((POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR0 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR1 end)/10.0))/2.0))*10 as SINR,
	MIN(case when t.band like '%LTE%' then t.signal end) as RSRP_min,		
	MIN(case when t.band like '%LTE%' then t.quality end) as RSRQ_min,		
	log10(MIN((POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR0 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR1 end)/10.0))/2.0))*10 as SINR_min,
	MAX(case when t.band like '%LTE%' then t.signal end) as RSRP_max,			
	MAX(case when t.band like '%LTE%' then t.quality end) as RSRQ_max,			
	log10(MAX((POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR0 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band  like '%LTE%' then 1.0 * t.SINR1 end)/10.0))/2.0))*10 as SINR_max,	
	
	-- Para las SCC 
	-- De momento solo para la SCC1
	log10(avg(power(10.0E0,(case when t.band_SCC1  like '%LTE%' then 1.0 * t.signal_SCC1 end)/10.0E0)))*10 as RSRP_SCC1,
	log10(avg(power(10.0E0,(case when t.band_SCC1  like '%LTE%' then 1.0 * t.quality_SCC1 end)/10.0E0)))*10 as RSRQ_SCC1,
	log10(AVG((POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR0_SCC1 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR1_SCC1 end)/10.0))/2.0))*10 as SINR_SCC1,
	MIN(case when t.band_SCC1 like '%LTE%' then t.signal_SCC1 end) as RSRP_min_SCC1,		
	MIN(case when t.band_SCC1 like '%LTE%' then t.quality_SCC1 end) as RSRQ_min_SCC1,		
	log10(MIN((POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR0_SCC1 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR1_SCC1 end)/10.0))/2.0))*10 as SINR_min_SCC1,
	MAX(case when t.band_SCC1 like '%LTE%' then t.signal_SCC1 end) as RSRP_max_SCC1,			
	MAX(case when t.band_SCC1 like '%LTE%' then t.quality_SCC1 end) as RSRQ_max_SCC1,			
	log10(MAX((POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR0_SCC1 end)/10.0) 
			+ POWER(CAST(10 AS float), (case when t.band_SCC1  like '%LTE%' then 1.0 * t.SINR1_SCC1 end)/10.0))/2.0))*10 as SINR_max_SCC1		
into _TECH_RADIO_AVG_Data
from lcc_Serving_Cell_Table t
where t.testid > @maxTestid
group by t.sessionid, t.testid
order by t.SessionId, t.testid

-------------- 
-- GSM/WCDMA/LTE Radio Initial (Radio Values)				
exec sp_lcc_dropifexists '_TECH_RADIO_INI_Data'			
select 
	t.sessionid, t.testid, t.longitude, t.latitude, 
	-- Para la PCC:
	case when t.band in ('GSM','DCS', 'EGSM') then t.Freq end as BCCH,
	case when t.band in ('GSM','DCS', 'EGSM') then t.signal end as RxLev,
	case when t.band in ('GSM','DCS', 'EGSM') then t.quality end as RxQual,
	case when t.band in ('GSM','DCS', 'EGSM') then t.cell end as BSIC,
	case when t.band like ('%UMTS%') then t.Freq end as UARFCN,
	case when t.band like ('%UMTS%') then t.signal end as RSCP,
	case when t.band like ('%UMTS%') then t.quality end as EcIo,
	case when t.band like ('%UMTS%') then t.cell end as PSC,
	t.RNCID,
	case when t.band like ('%LTE%') then t.Freq end as EARFCN,
	case when t.band like ('%LTE%') then t.signal end as RSRP,
	case when t.band like ('%LTE%') then t.quality end as RSRQ,
	case when t.band like ('%LTE%') then 
		(10*LOG10(
         (POWER(CAST(10 AS float), (t.SINR0)/10.0)
         +POWER(CAST(10 AS float), (t.SINR1)/10.0)
         )/2.0  ))									end as SINR,	
	case when t.band like ('%LTE%') then t.cell end as PCI,
	t.CId,
	t.LAC,
	-- @ERC: Se añade tecnologia inicio de test - correspondiente al primer msgid reportado
	t.band as Tech_Ini
	 
into _TECH_RADIO_INI_Data
from lcc_Serving_Cell_Table t
		left outer join 
				(Select sessionid, testid, min(id) as id
				 from lcc_Serving_Cell_Table where testid > @maxTestid
				 group by sessionid, testid) mi on t.SessionId=mi.SessionId
where t.id=mi.id 
	and t.testid > @maxTestid
order by t.SessionId, t.testid

--------------
-- GSM/WCDMA/LTE Radio Final (Radio Values)					
exec sp_lcc_dropifexists '_TECH_RADIO_FIN_Data'			
select 
	t.sessionid, t.testid, t.longitude, t.latitude,
	-- Para la PCC:	
	case when t.band in ('GSM','DCS', 'EGSM') then t.Freq end as BCCH,
	case when t.band in ('GSM','DCS', 'EGSM') then t.signal end as RxLev,
	case when t.band in ('GSM','DCS', 'EGSM') then t.quality end as RxQual,
	case when t.band in ('GSM','DCS', 'EGSM') then t.cell end as BSIC,
	case when t.band like ('%UMTS%') then t.Freq end as UARFCN,
	case when t.band like ('%UMTS%') then t.signal end as RSCP,
	case when t.band like ('%UMTS%') then t.quality end as EcIo,
	case when t.band like ('%UMTS%') then t.cell end as PSC,
	t.RNCID,
	case when t.band like ('%LTE%') then t.Freq end as EARFCN,
	case when t.band like ('%LTE%') then t.signal end as RSRP,
	case when t.band like ('%LTE%') then t.quality end as RSRQ,
	case when t.band like ('%LTE%') then 
		(10*LOG10(
         (POWER(CAST(10 AS float), (t.SINR0)/10.0)
         +POWER(CAST(10 AS float), (t.SINR1)/10.0)
         )/2.0  ))										end as SINR,	
	case when t.band like ('%LTE%') then t.cell end as PCI,
	t.CId,
	t.LAC,
	-- @ERC: Se añade tecnologia final de test - correspondiente al ultimo msgid reportado
	t.band as Tech_Fin
	 
into _TECH_RADIO_FIN_Data
from lcc_Serving_Cell_Table t
		left outer join 
				(Select sessionid, testid, max(id) as id
				 from lcc_Serving_Cell_Table where testid > @maxTestid
				 group by sessionid,testid)mi on t.SessionId=mi.SessionId
where t.id=mi.id 
	and t.testid > @maxTestid
order by t.SessionId, t.testid

--------------
-- Duraciones de cada entrada de la tabla por test id 
exec sp_lcc_dropifexists '_lcc_Serving_Cell_Table_duration_Data'			
select 
	ROW_NUMBER() over (partition by t.sessionid, t.testid order by t.msgtime asc) as durationID, * 
into _lcc_Serving_Cell_Table_duration_Data
from lcc_Serving_Cell_Table  t
where t.testid > @maxTestid
order by t.SessionId, t.testid

----------------
-- Calculos de las duraciones Serving Cell
exec sp_lcc_dropifexists '_TECH_RADIO_DURATION_Data'			
select 
	ini.*,
	ini.msgtime as msgtime_ini, 
	fin.MsgTime as MsgTime_fin, 
	datediff(ms, ini.msgtime, fin.MsgTime) as duration
into _TECH_RADIO_DURATION_Data
from _lcc_Serving_Cell_Table_duration_Data ini, _lcc_Serving_Cell_Table_duration_Data fin
where ini.durationID=fin.durationID-1
	and ini.SessionId=fin.SessionId and ini.TestId=fin.TestId

union all		-- se añade la duracion de la ultima entrada hasta el final del test (from Testinfo)
				-- desaparece la ultima linea de testid=0 al linkar con TestInfo - test en IDLE
select s.*, 
	s.MsgTime as msgtime_ini, 
	DATEADD(ms, t.duration , t.startTime) as msgtime_fin,
	datediff(ms, s.msgtime, DATEADD(ms, t.duration , t.startTime)) as duration
from _lcc_Serving_Cell_Table_duration_Data s, testinfo t,
	(select sessionid, testid, max(durationID) as msgid_last 
		from _lcc_Serving_Cell_Table_duration_Data 
		group by sessionid, testid  
		) ss 
where	t.SessionId=s.SessionId and t.TestId=s.TestId
	and s.durationID=ss.msgid_last and s.sessionid=ss.sessionid and s.TestId=ss.TestId
order by sessionid, testid, ini.durationID


-- DGP 19/10/2015: Se modifica la forma de calular el BW y se añade el desglosado por Freq faltante de 3G y LTE
-- *************************************************************************************************************

-- Duraciones de cada entrada para el BandWidth
exec sp_lcc_dropifexists '_lcc_BandWidth_Table_duration_Data'
select 
	ROW_NUMBER() over (partition by t.sessionid, t.testid order by t.msgtime asc) as durationID, * 
into _lcc_BandWidth_Table_duration_Data
from LTEServingCellInfo  t
where t.testid > @maxTestid
order by t.SessionId, t.testid

----------------
---- Calculos de las duraciones uso BandWidth
exec sp_lcc_dropifexists '_BW_RADIO_DURATION_Data'
select 
	ini.*,
	ini.msgtime as msgtime_ini, 
	fin.MsgTime as MsgTime_fin, 
	datediff(ms, ini.msgtime, fin.MsgTime) as duration
into _BW_RADIO_DURATION_Data
from _lcc_BandWidth_Table_duration_Data ini, _lcc_BandWidth_Table_duration_Data fin
where ini.durationID=fin.durationID-1
	and ini.SessionId=fin.SessionId and ini.TestId=fin.TestId
order by ini.sessionid, ini.testid, ini.durationid


--------------
-- Technology Use  
exec sp_lcc_dropifexists '_PCT_TECH_Data'			
select 
	td.sessionid, td.testid, 
	
	-- DGP 19/10/2015: Se añade el desglosado de todas las frecuencias de 3G y 4G
-- ***************************************************************************************************************

	-- Para U2100:
	1.0*sum(case when td.Freq in (10638,   10788,  10713,  10563) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_U2100,
	1.0*sum(case when td.Freq in (10663,	10813,	10738,	10588) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F2_U2100,
	1.0*sum(case when td.Freq in (10688,	10838,	10763,	10613) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F3_U2100,	
	-- Para U900:
	1.0*sum(case when td.Freq in (3062, 3011, 2959) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_U900,
	1.0*sum(case when td.Freq in (3087, 3022) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F2_U900,
	-- Para LTE2600:
	1.0*sum(case when td.Freq in (3250, 2850, 3050) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_L2600,
	-- Para LTE2100:
	1.0*sum(case when td.Freq in (326) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_L2100,
	1.0*sum(case when td.Freq in (426) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F2_L2100,
	-- Para LTE1800:
	1.0*sum(case when td.Freq in (1480, 1311, 1874, 1691) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_L1800,
	1.0*sum(case when td.Freq in (1501, 1321, 1899) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F2_L1800,
	1.0*sum(case when td.Freq in (1347) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F3_L1800,
	-- Para LTE800:
	1.0*sum(case when td.Freq in (6300, 6400, 6200) then td.duration end) / NULLIF(sum(td.duration),0) as pct_F1_L800,

-- *****************************************************************************************************************		
	-- Info solo para la PCC:
	1.0*sum(case when td.band like '%LTE%' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE,
	1.0*sum(case when td.band like '%UMTS%' then td.duration end) / NULLIF(sum(td.duration),0) as pctWCDMA,
	1.0*sum(case when td.band in ('GSM','DCS','EGSM') then td.duration end) / NULLIF(sum(td.duration),0) as pctGSM,

	1.0*sum(case when td.band like 'LTE800' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_800, 
	1.0*sum(case when td.band like 'LTE1800' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_1800,
	1.0*sum(case when td.band like 'LTE2100' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_2100,  
	1.0*sum(case when td.band like 'LTE2600' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_2600, 
	
	1.0*sum(case when td.band like 'UMTS2100' then td.duration end) / NULLIF(sum(td.duration),0) as pctUMTS_2100, 
	1.0*sum(case when td.band like 'UMTS900' then td.duration end) / NULLIF(sum(td.duration),0) as pctUMTS_900, 
	
	1.0*sum(case when td.band like 'DCS' then td.duration end) / NULLIF(sum(td.duration),0) as pctGMS_DCS, 
	1.0*sum(case when td.band like 'EGSM' then td.duration end) / NULLIF(sum(td.duration),0) as pctGSM_EGSM,
	1.0*sum(case when td.band like 'GSM' then td.duration end) / NULLIF(sum(td.duration),0) as pctGSM_GSM,

-- DGP 19/10/2015: Se deshabilita para hacer el cálculo de otra manera
-- ***************************************************************************************************************
	-- De momento se asigna el BW asi - mirar en capa 3 mensajes SIB
	--1.0*sum(case when (td.band like 'LTE_2600' or td.band like 'LTE_1800') and operator not like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band like 'LTE%' then td.duration end), 0) as pctLTE_20Mhz, 
			
	--1.0*sum(case when td.band like 'LTE_800' and operator not like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band like 'LTE%' then td.duration end), 0) as pctLTE_10Mhz, 	
	
	--1.0*sum(case when td.band like 'LTE_1800' and operator like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band like 'LTE%' then td.duration end), 0) as pctLTE_15Mhz,

-- DGP 10/02/2016: Se modifica para calcular bien el BW.
-- EL metodo antiguo es el de la linea del Else, y en caso de haber una sola linea por sid, tid sacaba null todo
-- *****************************************************************************************************************	
	-- Info de uso de BW
	case when max(b.durationid)=1 and max(b.DLBandWidth)=20 then  1.0
			 else 1.0*sum(case when bd.DLBandWidth=20 then bd.duration end) / NULLIF(sum(bd.duration),0)
			 end as pctLTE_20Mhz, 
			
		case when max(b.durationid)=1 and max(b.DLBandWidth)=15 then  1.0
			 else 1.0*sum(case when bd.DLBandWidth=15 then bd.duration end) / NULLIF(sum(bd.duration),0)
			 end as pctLTE_15Mhz, 	
	
		case when max(b.durationid)=1 and max(b.DLBandWidth)=10 then  1.0
			 else 1.0*sum(case when bd.DLBandWidth=10 then bd.duration end) / NULLIF(sum(bd.duration),0)
			 end as pctLTE_10Mhz, 

	
	-- Info solo para la SCC1 de momento:
	1.0*sum(case when td.band_SCC1 like 'LTE800' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_800_SCC1, 
	1.0*sum(case when td.band_SCC1 like 'LTE1800' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_1800_SCC1, 
	1.0*sum(case when td.band_SCC1 like 'LTE2600' then td.duration end) / NULLIF(sum(td.duration),0) as pctLTE_2600_SCC1,

-- DGP 19/10/2015: Se deshabilita para hacer el cálculo de otra manera
-- *************************************************************************************************************************			
	-- De momento se asigna el BW asi - mirar en capa 3 mensajes SIB
	--1.0*sum(case when (td.band_SCC1 like 'LTE_2600' or td.band_SCC1 like 'LTE_1800') and operator not like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band_SCC1 like 'LTE%' then td.duration end), 0) as pctLTE_20Mhz_SCC1, 
			
	--1.0*sum(case when (td.band_SCC1 like 'LTE_800') and operator not like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band_SCC1 like 'LTE%' then td.duration end), 0) as pctLTE_10Mhz_SCC1, 	
	
	--1.0*sum(case when td.band_SCC1 like 'LTE_1800' and operator like 'Yoigo' 
	--		then td.duration end) / NULLIF(1.0*sum(case when td.band_SCC1 like 'LTE%' then td.duration end), 0) as pctLTE_15Mhz_SCC1	
-- **************************************************************************************************************************
-- La tabla utilizada no tiene info de las portadoras secundarias de momento se deja a null
	null pctLTE_20Mhz_SCC1,
	null pctLTE_15Mhz_SCC1,
	null pctLTE_10Mhz_SCC1

into _PCT_TECH_Data
from _TECH_RADIO_DURATION_Data td
		left outer join _BW_RADIO_DURATION_Data bd on bd.sessionid=td.sessionid and bd.testid=td.testid
		left outer join _lcc_BandWidth_Table_duration_Data b on b.sessionid=td.sessionid and b.testid=td.testid
where td.band is not NULL
group by td.sessionid, td.TestId
order by td.sessionid, td.TestId



------------------------------ (2) DL/UL Modulaciones, Shared Channel Use, RBs, Transmission Mode INFO 4G 	------------------------------
--select 'Se crean las tablas intermedias: (2) DL/UL Modulaciones, Shared Channel Use, RBs, Transmission Mode INFO 4G ' info
----------------
-- RBs DL:
exec sp_lcc_dropifexists '_RBs_carrier_DL'			
select 
	l.direction, l.sessionid, l.testid,
	-- PCC:
	AVG(ROUND((1.0*l.num_RBs_num_PCC/num_RBs_den_PCC),0)) as num_RBs_PCC,
	--Min entre el max y 100 (máximo teórico de RBS): 0.5 * ((@val1 + @val2) - ABS(@val1 - @val2)) 
	0.5 * ((CEILING(max(ROUND((1.0*l.num_RBs_num_PCC/num_RBs_den_PCC),0))) + 100) - ABS(CEILING(max(ROUND((1.0*l.num_RBs_num_PCC/num_RBs_den_PCC),0))) - 100)) as maxRBs_PCC,		-- max de los numRB
	FLOOR(MIN(ROUND((1.0*l.num_RBs_num_PCC/num_RBs_den_PCC),0))) as minRBs_PCC,			-- min de los numRBs
	AVG(ROUND(1.0*l.num_RBs_num_PCC/(num_RBs_den_PCC),0)) as Rbs_round_PCC,
	AVG(case when isnull(l.num_RBs_den_dedicated_PCC,0)=0 then 0 else ROUND(1.0*l.num_RBs_num_PCC/l.num_RBs_den_dedicated_PCC,0) end) as Rbs_dedicated_round_PCC,	
	
	-- SCC1:
	AVG(ROUND((1.0*l.num_RBs_num_SCC1/num_RBs_den_SCC1),0)) as num_RBs_SCC1,
	--Min entre el max y 100 (máximo teórico de RBS): 0.5 * ((@val1 + @val2) - ABS(@val1 - @val2)) 
	0.5 * ((CEILING(max(ROUND((1.0*l.num_RBs_num_SCC1/num_RBs_den_SCC1),0))) + 100) - ABS(CEILING(max(ROUND((1.0*l.num_RBs_num_SCC1/num_RBs_den_SCC1),0))) - 100))  as maxRBs_SCC1,		-- max de los numRB
	FLOOR(MIN(ROUND((1.0*l.num_RBs_num_SCC1/num_RBs_den_SCC1),0))) as minRBs_SCC1,			-- min de los numRBs
	AVG(ROUND(l.num_RBs_num_SCC1/(num_RBs_den_SCC1),0)) as Rbs_round_SCC1,
	AVG(case when isnull(l.num_RBs_den_dedicated_SCC1,0)=0 then 0 else ROUND(1.0*l.num_RBs_num_SCC1/l.num_RBs_den_dedicated_SCC1,0) end) as Rbs_dedicated_round_SCC1,
	-- @DGP: codigo para CA
	sum(case when l.num_RBs_num_SCC1 is null then 1 end) as Blocks_NoCA,
	isnull(sum(case when l.num_RBs_num_SCC1 is not null then 1 end),0) as Blocks_CA,
	100.0*isnull(sum(case when l.num_RBs_num_SCC1 is not null then 1.0 end),0)/nullif(isnull(count(l.sessionid),0),0) as [% CA]

into _RBs_carrier_DL	
from lcc_Physical_Info_Table l
where l.[Info about]='4G' 	-- Info LTE - PDSCH / PUSCH
	and l.direction='Downlink'
	and l.testId > @maxTestid
group by  l.direction, l.sessionid, l.testid
order by l.sessionid, l.testid

----------------
-- RBs DL:
exec sp_lcc_dropifexists '_RBs_DL'			
select 
	l.direction, l.sessionid, l.testid,
	-- ALL:
	sum(isnull(num_RBs_PCC,0)+isnull(num_RBs_SCC1,0)) as num_RBs,
	sum(isnull(maxRBs_PCC,0)+isnull(maxRBs_SCC1,0)) as maxRBs,		-- max de los numRB
	sum(isnull(minRBs_PCC,0)+isnull(minRBs_SCC1,0)) as minRBs,		-- min de los numRBs
	
	sum(isnull(Rbs_round_PCC,0)+isnull(Rbs_round_SCC1,0)) as Rbs_round,
	sum(isnull(Rbs_dedicated_round_PCC,0)+isnull(Rbs_dedicated_round_SCC1,0)) as Rbs_dedicated_round
into _RBs_DL	
from _RBs_carrier_DL l
group by  l.direction, l.sessionid, l.testid
order by l.sessionid, l.testid

----------------
--  RBs UL:
exec sp_lcc_dropifexists '_RBs_UL'			
select 
	l.direction, l.sessionid, l.testid,
	AVG(ROUND(1.0*(l.num_RBs_num/num_RBs_den),0)) as num_RBs,
	--Min entre el max y 50 (máximo teórico de RBS): 0.5 * ((@val1 + @val2) - ABS(@val1 - @val2)) 
	0.5 * ((CEILING(max(ROUND(1.0*(l.num_RBs_num/num_RBs_den),0))) + 50) - ABS(CEILING(max(ROUND(1.0*(l.num_RBs_num/num_RBs_den),0))) - 50)) as maxRBs,		-- max de los numRB
	FLOOR(MIN(ROUND(1.0*(l.num_RBs_num/num_RBs_den),0))) as minRBs,			-- min de los numRBs
	AVG(ROUND(1.0*l.num_RBs_num/(num_RBs_den),0)) as Rbs_round,
	AVG(case when isnull(l.num_RBs_den_dedicated,0)=0 then 0 else ROUND(1.0*l.num_RBs_num/l.num_RBs_den_dedicated,0) end) as Rbs_dedicated_round
into _RBs_UL	
from lcc_Physical_Info_Table l
where l.[Info about]='4G' 	-- Info LTE - PDSCH / PUSCH
	and direction='Uplink'
	and l.testId > @maxTestid
group by  l.direction, l.sessionid, l.testid
order by l.sessionid, l.testid

----------------
-- Modulaciones 4G 
exec sp_lcc_dropifexists '_MOD_4G'			
select 
	l.direction, l.sessionid, l.testid,
	1.0*SUM(1.0*l.use_BPSK_num) / NULLIF(SUM(l.mod_use_denom),0) as '% BPSK',
	1.0*SUM(1.0*l.use_QPSK_num) / NULLIF(SUM(l.mod_use_denom),0) as '% QPSK',
	1.0*SUM(1.0*l.use_16QAM_num) / NULLIF(SUM(l.mod_use_denom),0) as '% 16QAM',
	1.0*SUM(1.0*l.use_64QAM_num) / NULLIF(SUM(l.mod_use_denom),0) as '% 64QAM',
	
	-- PCC
	--1.0*SUM(1.0*l.use_BPSK_num_PCC) / NULLIF(SUM(l.mod_use_denom_PCC),0) as '% BPSK PCC',
	1.0*SUM(1.0*l.use_QPSK_num_PCC) / NULLIF(SUM(l.mod_use_denom_PCC),0) as '% QPSK PCC',
	1.0*SUM(1.0*l.use_16QAM_num_PCC) / NULLIF(SUM(l.mod_use_denom_PCC),0) as '% 16QAM PCC',
	1.0*SUM(1.0*l.use_64QAM_num_PCC) / NULLIF(SUM(l.mod_use_denom_PCC),0) as '% 64QAM PCC',
	
	-- SCC1
	--1.0*SUM(1.0*l.use_BPSK_num_SCC1) / NULLIF(SUM(l.mod_use_denom_SCC1),0) as '% BPSK SCC1',
	1.0*SUM(1.0*l.use_QPSK_num_SCC1) / NULLIF(SUM(l.mod_use_denom_SCC1),0) as '% QPSK SCC1',
	1.0*SUM(1.0*l.use_16QAM_num_SCC1) / NULLIF(SUM(l.mod_use_denom_SCC1),0) as '% 16QAM SCC1',
	1.0*SUM(1.0*l.use_64QAM_num_SCC1) / NULLIF(SUM(l.mod_use_denom_SCC1),0) as '% 64QAM SCC1'	
	
into _MOD_4G
from lcc_Physical_Info_Table l 
where l.[Info about]='4G'								-- Info LTE - PDSCH / PUSCH
	and l.testId > @maxTestid
group by l.direction, l.sessionid, l.testid

----------------
-- Shared Channel Use 4G  - este si es la suma de ambas carriers
exec sp_lcc_dropifexists '_SCCH_USE_4G'			
select 
	direction, sessionid, testid,
	1.0*SUM(1.0*l.LTESharedChannelUse_num) / NULLIF(SUM(l.LTESharedChannelUse_den),0) as 'Percent_LTESharedChannelUse',
	-- PCC:
	1.0*SUM(1.0*l.LTESharedChannelUse_num_PCC) / NULLIF(SUM(l.LTESharedChannelUse_den_PCC),0) as 'Percent_LTESharedChannelUse_PCC',
	-- SCC1:
	1.0*SUM(1.0*l.LTESharedChannelUse_num_SCC1) / NULLIF(SUM(l.LTESharedChannelUse_den_SCC1),0) as 'Percent_LTESharedChannelUse_SCC1'
into _SCCH_USE_4G	
from lcc_Physical_Info_Table l 
where l.[Info about]='4G' 					-- Info LTE - PDSCH / PUSCH
	and l.testId > @maxTestid
group by direction, sessionid, testid

----------------
-- Transmission Mode 4G DL	
exec sp_lcc_dropifexists '_TM_DL'			
select 
	direction, sessionid, testid, 
	1.0*SUM(case when TransmissionMode=0 then 1 else 0 end)/SUM(1) as 'percTM0',
	1.0*SUM(case when TransmissionMode=1 then 1 else 0 end)/SUM(1) as 'percTM1',
	1.0*SUM(case when TransmissionMode=2 then 1 else 0 end)/SUM(1) as 'percTM2',
	1.0*SUM(case when TransmissionMode=3 then 1 else 0 end)/SUM(1) as 'percTM3',
	1.0*SUM(case when TransmissionMode=4 then 1 else 0 end)/SUM(1) as 'percTM4',
	1.0*SUM(case when TransmissionMode=5 then 1 else 0 end)/SUM(1) as 'percTM5', 
	1.0*SUM(case when TransmissionMode=6 then 1 else 0 end)/SUM(1) as 'percTM6', 
	1.0*SUM(case when TransmissionMode=7 then 1 else 0 end)/SUM(1) as 'percTM7',
	1.0*SUM(case when TransmissionMode is NULL then 1 else 0 end)/SUM(1) as 'percTMunknown',	 

	-- PCC:
	1.0*SUM(case when TransmissionMode_PCC=0 then 1 else 0 end)/SUM(1) as 'percTM0 PCC',
	1.0*SUM(case when TransmissionMode_PCC=1 then 1 else 0 end)/SUM(1) as 'percTM1 PCC',
	1.0*SUM(case when TransmissionMode_PCC=2 then 1 else 0 end)/SUM(1) as 'percTM2 PCC',
	1.0*SUM(case when TransmissionMode_PCC=3 then 1 else 0 end)/SUM(1) as 'percTM3 PCC',
	1.0*SUM(case when TransmissionMode_PCC=4 then 1 else 0 end)/SUM(1) as 'percTM4 PCC',
	1.0*SUM(case when TransmissionMode_PCC=5 then 1 else 0 end)/SUM(1) as 'percTM5 PCC', 
	1.0*SUM(case when TransmissionMode_PCC=6 then 1 else 0 end)/SUM(1) as 'percTM6 PCC', 
	1.0*SUM(case when TransmissionMode_PCC=7 then 1 else 0 end)/SUM(1) as 'percTM7 PCC',
	1.0*SUM(case when TransmissionMode_PCC is NULL then 1 else 0 end)/SUM(1) as 'percTMunknown PCC',
	
	-- SCC1:
	1.0*SUM(case when TransmissionMode_SCC1=0 then 1 else 0 end)/SUM(1) as 'percTM0 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1=1 then 1 else 0 end)/SUM(1) as 'percTM1 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1=2 then 1 else 0 end)/SUM(1) as 'percTM2 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1=3 then 1 else 0 end)/SUM(1) as 'percTM3 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1=4 then 1 else 0 end)/SUM(1) as 'percTM4 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1=5 then 1 else 0 end)/SUM(1) as 'percTM5 SCC1', 
	1.0*SUM(case when TransmissionMode_SCC1=6 then 1 else 0 end)/SUM(1) as 'percTM6 SCC1', 
	1.0*SUM(case when TransmissionMode_SCC1=7 then 1 else 0 end)/SUM(1) as 'percTM7 SCC1',
	1.0*SUM(case when TransmissionMode_SCC1 is NULL then 1 else 0 end)/SUM(1) as 'percTMunknown SCC1'
		
into _TM_DL     
from lcc_Physical_Info_Table l 
where l.[Info about]='4G'								-- Info LTE - PDSCH / PUSCH
		and l.testId > @maxTestid
group by direction, sessionid, testid



------------------------------ (3) CQI, AverageRI 4G  ------------------------------
--select 'Se crean las tablas intermedias: (3) CQI, AverageRI 4G' info
----------------
-- Info SCC:
exec sp_lcc_dropifexists '_SCC_CQI'			
CREATE TABLE _SCC_CQI(
	[sessionid] [bigint] NULL,
	[TestId] [bigint] NULL,
	[LTEPUCCHCQIId] [bigint] NULL,
	[CarrierIndex] [smallint] NULL,
	[TxMode] [tinyint] NULL,
	[RankIndex] [int] NULL,
	[PMI] [tinyint] NULL,
	[NumSamplesCQI0] [int] NULL,
	[NumSamplesCQI1] [int] NULL,
	[CQI0] [real] NULL,
	[CQI1] [real] NULL	)
	
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LTEPUCCHCQICarrier]') AND type in (N'U'))
begin
	insert 	into _SCC_CQI
	select 
		sessionid, TestId, 	
		c.LTEPUCCHCQIId,
		c.CarrierIndex,						-- para SCC
		c.TxMode,
		c.RankIndex + 1 as RankIndex,		-- viene de la vista asi - - valores 0 o 1 - fran tiene otra cosa en las vistas - revisar
		c.PMI,
		c.NumSamplesCQI0,
		c.NumSamplesCQI1,
		c.CQI0,
		c.CQI1
	from LTEPUCCHCQI l
		JOIN LTEPUCCHCQICarrier c ON c.LTEPUCCHCQIId = l.LTEPUCCHCQIId
	where l.testId > @maxTestid
end

----------------
-- Añadimos info de las SCC al de la PCC:
exec sp_lcc_dropifexists '_PUCCHCQI_4G'			
select 
	pcc.sessionid, pcc.TestId, 				-- para PCC
	tech.band,
	null as LTEPUCCHCQIId,	pcc.TxMode,
	pcc.RankIndex + 1 as RankIndex,			-- viene de la vista asi - valores 0 o 1
	pcc.PMI,	pcc.NumSamplesCQI0,	pcc.NumSamplesCQI1,
	pcc.CQI0,	pcc.CQI1,
	s1.TxMode as TxMode_SCC1, s1.RankIndex + 1 as RankIndex_SCC1, s1.PMI as PMI_SCC1, s1.NumSamplesCQI0 as NumSamplesCQI0_SCC1, s1.NumSamplesCQI1 as NumSamplesCQI1_SCC1, s1.CQI0 as CQI0_SCC1, s1.CQI1 as CQI1_SCC1,
	s2.TxMode as TxMode_SCC2, s2.RankIndex + 1 as RankIndex_SCC2, s2.PMI as PMI_SCC2, s2.NumSamplesCQI0 as NumSamplesCQI0_SCC2, s2.NumSamplesCQI1 as NumSamplesCQI1_SCC2, s2.CQI0 as CQI0_SCC2, s2.CQI1 as CQI1_SCC2,
	s3.TxMode as TxMode_SCC3, s3.RankIndex + 1 as RankIndex_SCC3, s3.PMI as PMI_SCC3, s3.NumSamplesCQI0 as NumSamplesCQI0_SCC3, s3.NumSamplesCQI1 as NumSamplesCQI1_SCC3, s3.CQI0 as CQI0_SCC3, s3.CQI1 as CQI1_SCC3,
	s4.TxMode as TxMode_SCC4, s4.RankIndex + 1 as RankIndex_SCC4, s4.PMI as PMI_SCC4, s4.NumSamplesCQI0 as NumSamplesCQI0_SCC4, s4.NumSamplesCQI1 as NumSamplesCQI1_SCC4, s4.CQI0 as CQI0_SCC4, s4.CQI1 as CQI1_SCC4,
	s5.TxMode as TxMode_SCC5, s5.RankIndex + 1 as RankIndex_SCC5, s5.PMI as PMI_SCC5, s5.NumSamplesCQI0 as NumSamplesCQI0_SCC5, s5.NumSamplesCQI1 as NumSamplesCQI1_SCC5, s5.CQI0 as CQI0_SCC5, s5.CQI1 as CQI1_SCC5,
	s6.TxMode as TxMode_SCC6, s6.RankIndex + 1 as RankIndex_SCC6, s6.PMI as PMI_SCC6, s6.NumSamplesCQI0 as NumSamplesCQI0_SCC6, s6.NumSamplesCQI1 as NumSamplesCQI1_SCC6, s6.CQI0 as CQI0_SCC6, s6.CQI1 as CQI1_SCC6,
	s7.TxMode as TxMode_SCC7, s7.RankIndex + 1 as RankIndex_SCC7, s7.PMI as PMI_SCC7, s7.NumSamplesCQI0 as NumSamplesCQI0_SCC7, s7.NumSamplesCQI1 as NumSamplesCQI1_SCC7, s7.CQI0 as CQI0_SCC7, s7.CQI1 as CQI1_SCC7
	
into _PUCCHCQI_4G
from LTEPUCCHCQI pcc
	inner join _TECH_RADIO_DURATION_Data tech 
		on pcc.sessionid=tech.sessionid and pcc.testid=tech.testid 
			and tech.msgtime_ini <= pcc.MsgTime and pcc.MsgTime <tech.MsgTime_fin
	LEFT OUTER JOIN _SCC_CQI s1 on (pcc.LTEPUCCHCQIId=s1.LTEPUCCHCQIId and s1.CarrierIndex=1)
	LEFT OUTER JOIN _SCC_CQI s2 on (pcc.LTEPUCCHCQIId=s2.LTEPUCCHCQIId and s2.CarrierIndex=2)
	LEFT OUTER JOIN _SCC_CQI s3 on (pcc.LTEPUCCHCQIId=s3.LTEPUCCHCQIId and s3.CarrierIndex=3)
	LEFT OUTER JOIN _SCC_CQI s4 on (pcc.LTEPUCCHCQIId=s4.LTEPUCCHCQIId and s4.CarrierIndex=4)
	LEFT OUTER JOIN _SCC_CQI s5 on (pcc.LTEPUCCHCQIId=s5.LTEPUCCHCQIId and s5.CarrierIndex=5)
	LEFT OUTER JOIN _SCC_CQI s6 on (pcc.LTEPUCCHCQIId=s6.LTEPUCCHCQIId and s6.CarrierIndex=6)
	LEFT OUTER JOIN _SCC_CQI s7 on (pcc.LTEPUCCHCQIId=s7.LTEPUCCHCQIId and s7.CarrierIndex=7)
where pcc.testId > @maxTestid	
order by pcc.sessionid, pcc.TestId		

----------------
-- CQI 4G
exec sp_lcc_dropifexists '_CQI_4G'			
select 
	sessionid, TestId, 
	-- PCC:	
	AVG(CQI0) as averageCQI0,	AVG(CQI1) as averageCQI1,	AVG(RankIndex) as AverageRI, 
	
	-- SCC1:	- De momento los para la SCC1
	AVG(CQI0_SCC1) as averageCQI0_SCC1,	AVG(CQI1_SCC1) as averageCQI1_SCC1,	AVG(RankIndex_SCC1) as AverageRI_SCC1
	
into _CQI_4G
from _PUCCHCQI_4G 
group by sessionid, TestId
order by sessionid, TestId


-- CQI 4G Band
exec sp_lcc_dropifexists '_CQI_4G_Band'			
select 
	sessionid, TestId, 
	case when band like 'LTE2600' then AVG(CQI1)
		else null end AS 'averageCQI1_LTE2600',
	case when band like 'LTE2600' then AVG(CQI0)
		else null end AS 'averageCQI0_LTE2600',
	case when band like 'LTE800' then AVG(CQI1)
		else null end AS 'averageCQI1_LTE800',
	case when band like 'LTE800' then AVG(CQI0)
		else null end AS 'averageCQI0_LTE800',
	case when band like 'LTE2100' then AVG(CQI1)
		else null end AS 'averageCQI1_LTE2100',
	case when band like 'LTE2100' then AVG(CQI0)
		else null end AS 'averageCQI0_LTE2100',
	case when band like 'LTE1800' then AVG(CQI1)
		else null end AS 'averageCQI1_LTE1800',
	case when band like 'LTE1800' then AVG(CQI0)
		else null end AS 'averageCQI0_LTE1800',
	case when band like 'LTE2600' then 'LTE2600'
		when band like 'LTE800' then 'LTE800'
		when band like 'LTE2100' then 'LTE2100'
		when band like 'LTE1800' then 'LTE1800'
		else '' end as 'Band'	
into _CQI_4G_Band
from _PUCCHCQI_4G 
group by sessionid, TestId,band
order by sessionid, TestId


----------------
-- Transmission Mode 4G UL	
exec sp_lcc_dropifexists '_TM_UL'			
select 
	sessionid, testid, 		
	-- PCC:
	1.0*SUM(case when TxMode=0 then 1 else 0 end)/SUM(1) as 'percTM0',
	1.0*SUM(case when TxMode=1 then 1 else 0 end)/SUM(1) as 'percTM1',
	1.0*SUM(case when TxMode=2 then 1 else 0 end)/SUM(1) as 'percTM2',
	1.0*SUM(case when TxMode=3 then 1 else 0 end)/SUM(1) as 'percTM3',
	1.0*SUM(case when TxMode=4 then 1 else 0 end)/SUM(1) as 'percTM4',
	1.0*SUM(case when TxMode=5 then 1 else 0 end)/SUM(1) as 'percTM5',   
	1.0*SUM(case when TxMode=6 then 1 else 0 end)/SUM(1) as 'percTM6',   
	1.0*SUM(case when TxMode=7 then 1 else 0 end)/SUM(1) as 'percTM7',   
	1.0*SUM(case when TxMode=8 then 1 else 0 end)/SUM(1) as 'percTM8',
	1.0*SUM(case when TxMode=9 then 1 else 0 end)/SUM(1) as 'percTM9',
	1.0*SUM(case when TxMode is NULL then 1 else 0 end)/SUM(1) as 'percTMunknown',
	
	-- SCC1:	- De momento solo para la SCC1
	1.0*SUM(case when TxMode_SCC1=0 then 1 else 0 end)/SUM(1) as 'percTM0_SCC1',
	1.0*SUM(case when TxMode_SCC1=1 then 1 else 0 end)/SUM(1) as 'percTM1_SCC1',
	1.0*SUM(case when TxMode_SCC1=2 then 1 else 0 end)/SUM(1) as 'percTM2_SCC1',
	1.0*SUM(case when TxMode_SCC1=3 then 1 else 0 end)/SUM(1) as 'percTM3_SCC1',
	1.0*SUM(case when TxMode_SCC1=4 then 1 else 0 end)/SUM(1) as 'percTM4_SCC1',
	1.0*SUM(case when TxMode_SCC1=5 then 1 else 0 end)/SUM(1) as 'percTM5_SCC1',   
	1.0*SUM(case when TxMode_SCC1=6 then 1 else 0 end)/SUM(1) as 'percTM6_SCC1',   
	1.0*SUM(case when TxMode_SCC1=7 then 1 else 0 end)/SUM(1) as 'percTM7_SCC1',   
	1.0*SUM(case when TxMode_SCC1=8 then 1 else 0 end)/SUM(1) as 'percTM8_SCC1',
	1.0*SUM(case when TxMode_SCC1=9 then 1 else 0 end)/SUM(1) as 'percTM9_SCC1',
	1.0*SUM(case when TxMode_SCC1 is NULL then 1 else 0 end)/SUM(1) as 'percTMunknown_SCC1'	
			   
into _TM_UL     
from _PUCCHCQI_4G group by sessionid, testid



------------------------------ (4) CQI, ACKs, NACks, DTX, HS BLER y Uso de Dual Carrier 3G  ------------------------------
--select 'Se crean las tablas intermedias: (4) CQI, ACKs, NACks, DTX, HS BLER y Uso de Dual Carrier 3G' info

-- DGP 29/10/2015: Se linka con la tabla networkinfo para sacar las tecnologías usadas en cada test y así desglosar por banda el DC
-- *********************************************************************************************************************************
----------------
exec sp_lcc_dropifexists '_CQI_3G'			
select 
	h.sessionid, h.TestId,
	case when sum(h.NumCQI)= 0 then null 	else sum(1.0*h.sumCQI)/sum(h.NumCQI) end AS CQI,
	sum(1.0*h.SumCQI_C0)/case when sum(h.NumCQI_C0)=0 then 1 else sum(h.NumCQI_C0)end AS CQI_c0,
	sum(1.0*h.SumCQI_C1)/case when sum(h.NumCQI_C1)=0 then 1 else sum(h.NumCQI_C1)end AS CQI_c1,
	case when sum(h.numsamples)=0 then 0.0 else 1.0*sum(h.numack)/sum(h.NumSamples) end as NumAck_DL,
	case when sum(h.numsamples)=0 then 0.0 else 1.0*sum(h.numNack)/sum(h.NumSamples) end as NumNack_DL,
	case when sum(h.numsamples)=0 then 0.0 else 1.0*sum(h.numDTX)/sum(h.numSamples) end as numDtx_DL,
	sum(h.numack) as ackNum,	sum(h.numNack) as nackNum,	sum(h.numDTX) as dtxnum,	sum(h.numsamples) as numsamples,
	AVG(h.BLER) as avgBLER,	1.0*SUM(h.EnabledDualCarrier)/SUM(1) as DualCarrier_use,
	1.0*sum(case when (n.technology='UMTS 2100') then h.EnabledDualCarrier else 0.0 end)/SUM(1) as DualCarrier_use_U2100,
	1.0*sum(case when (n.technology='UMTS 900') then h.EnabledDualCarrier else 0.0 end)/SUM(1) as DualCarrier_use_U900

into _CQI_3G	

from HSDPACQI h,	-- 	contains data for the UL DPCCH	
networkinfo n

where n.networkid=h.networkid
and h.testId > @maxTestid	

group by h.sessionid,h.TestId



exec sp_lcc_dropifexists '_CQI_3G_Band'			
select 
	h.sessionid, h.TestId,
	case when band like 'UMTS900' then (case when sum(NumCQI)= 0 then null else sum(1.0*sumCQI)/sum(NumCQI) end)
		else null end AS 'CQI_UMTS900',
	case when band like 'UMTS2100' then (case when sum(NumCQI)= 0 then null else sum(1.0*sumCQI)/sum(NumCQI) end)
		else null end AS 'CQI_UMTS2100',
	case when band like 'UMTS900' then 'UMTS900'
		when band like 'UMTS2100' then 'UMTS2100'
		else '' end as 'Band'
into _CQI_3G_Band
from HSDPACQI h	-- 	contains data for the UL DPCCH	
inner join _TECH_RADIO_DURATION_Data tech on h.sessionid=tech.sessionid and h.testid=tech.testid 
						and tech.msgtime_ini <= h.MsgTime and h.MsgTime <tech.MsgTime_fin,
networkinfo n

where n.networkid=h.networkid
and h.testId > @maxTestid	

group by h.sessionid,h.TestId, band



------------------------------ (5) Modulaciones, Codigos, Uso Dual Carrier y Retransmisiones 3G ------------------------------
--select 'Se crean las tablas intermedias: (5) Modulaciones, Codigos, Uso Dual Carrier y Retransmisiones 3G' info

-- DGP 29/10/2015: Se linka con la tabla networkinfo para sacar las tecnologías usadas en cada test y así desglosar por banda el DC
-- *********************************************************************************************************************************
-- DGP 19/05/2016: Se cambia la forma de calcular el uso de códigos, pues en QPs cuando hay SC no se rellena el desglose por Carrier
-- *********************************************************************************************************************************

----------------
exec sp_lcc_dropifexists '_MOD_3G'			
select 
	h.testid, h.sessionid, 
	case when sum(h.numsamples)=0 then 0.0 else 1.0*SUM(h.modschemeqpsk)/SUM(h.numsamples) end as Percent_QPSK,
	case when sum(h.numsamples)=0 then 0.0 else 1.0*SUM(h.ModScheme16QAM)/SUM(h.numsamples) end  as Percent_16QAM,
	case when sum(h.numsamples)=0 then 0.0 else 1.0*SUM(h.ModScheme64QAM)/SUM(h.numsamples) end  as Percent_64QAM,
	--AVG(1.0*h.AvgNumCodeChannels_C0+h.AvgNumCodeChannels_C1) AS Average_codes,
	--AVG(1.0*h.AvgNumCodeChannels_C0) AS Average_codes_C0,

	case when (AVG(h.AvgNumCodeChannels_C0) is null and AVG(h.AvgNumCodeChannels_C0) is null) then AVG(1.0*h.AvgNumCodeChannels)
		 else AVG(1.0*h.AvgNumCodeChannels_C0+h.AvgNumCodeChannels_C1)
		 end AS Average_codes,
	case when AVG(h.AvgNumCodeChannels_C0) is null then AVG(1.0*h.AvgNumCodeChannels)
		 else AVG(1.0*h.AvgNumCodeChannels_C0)
		 end AS Average_codes_C0,
	
	AVG(1.0*h.AvgNumCodeChannels_C1) AS Average_codes_C1,	
	
	--MAX(h.AvgNumCodeChannels_C0+h.AvgNumCodeChannels_C1) AS max_codes,
	--MAX(h.AvgNumCodeChannels_C0) AS max_codes_C0,
	
	case when (MAX(h.AvgNumCodeChannels_C0) is null and MAX(h.AvgNumCodeChannels_C0) is null) then MAX(1.0*h.AvgNumCodeChannels)
		 else MAX(1.0*h.AvgNumCodeChannels_C0+h.AvgNumCodeChannels_C1)
		 end AS max_codes,
	case when MAX(h.AvgNumCodeChannels_C0) is null then MAX(h.AvgNumCodeChannels)
		 else MAX(1.0*h.AvgNumCodeChannels_C0)
		 end AS max_codes_C0,

	MAX(h.AvgNumCodeChannels_C1) AS max_codes_C1,
	
	1.0*SUM(h.EnabledDualCarrier)/SUM(1) as DualCarrier_use,
	1.0*sum(case when (n.technology='UMTS 2100') then h.EnabledDualCarrier else 0.0 end)/SUM(1) as DualCarrier_use_U2100,
	1.0*sum(case when (n.technology='UMTS 900') then h.EnabledDualCarrier else 0.0 end)/SUM(1) as DualCarrier_use_U900,
	SUM(h.NumRetransmissions) as sumNumRetransmissions,
	AVG(h.RateRetransmissions) as avgRateRetransmissions
into _MOD_3G
from HSDPAModulation h,
networkinfo n

where n.networkid=h.networkid
and AvgNumCodeChannels <> 0 -- DGP 17/09/2015: se descartan los tests con code=0 por darse en periodos de negociación de la medida
and testId > @maxTestid	 
group by testid, sessionid



------------------------------ (6) HSSCH_Use 3G ------------------------------
--select 'Se crean las tablas intermedias: (6) HSSCH_Use 3G' info
----------------
exec sp_lcc_dropifexists '_SCCH_USE_3G'			
select 
	sessionid, testid, 1.0*sum(numScchValid)/nullif(sum(numscchdecodeattempted),0) as hscch_use 
into _SCCH_USE_3G
from HSDPAScch
where testId > @maxTestid	
group by sessionid, testid



------------------------------ (7) HARQ_PROCESSES 3G  ------------------------------
--select 'Se crean las tablas intermedias: (7) HARQ_PROCESSES 3G' info			
----------------
exec sp_lcc_dropifexists '_HARQ'			
select 
	sessionid, testid, AVG(NumHarqProc) as NumHarqProc_avg 
into _HARQ	
from HSDPAHarq
where testId > @maxTestid	
group by sessionid, testid


------------------------------ (8) Serving Grant, TTI, HappyRate, DTX, TBs y Retransmisiones 3G ------------------------------
--select 'Se crean las tablas intermedias: (8) Serving Grant, TTI, HappyRate, DTX, TBs y Retransmisiones 3G' info			
----------------
exec sp_lcc_dropifexists '_ULMAC'			
select 
	sessionid, TestId, 
	AVG(AverageSG) as AverageSG, 
	SUM(case when TTI=10 then 1 end) as sumTTI_10ms, 	SUM(case when TTI=2 then 1 end) as sumTTI_2ms, 
	SUM(case when TTI in (2,10) then 1 end) as sumTTI_ms, 		
	AVG(HappyRate) as AverageHappyRate, 	max(HappyRate) as maxHappyRate,
	AVG(DTXRate) as AverageDTXRate, 	AVG(convert(bigint,AverageTBsize)) as AverageTBsize,
	AVG(RetransRate) as avgRetransRate
into _ULMAC
from lcc_Physical_Info_Table 
where [Info about]='3G' and Direction='Uplink'
	and testId > 0	
group by testid, sessionid		


------------------------------ (9) Spreading Factor ------------------------------
--select 'Se crean las tablas intermedias: (9) Spreading Factor' info			
---------------- 
exec sp_lcc_dropifexists '_tSF'			
select 
	sessionid, TestId, 
	SUM(DurationSF42) as sumDurationSF42,			-- duracion 2*SF4 activo
	sum(DurationSF22) as sumDurationSF22,			-- duracion 2*SF2 activo
	SUM(DurationSF4) as sumDurationSF4,						-- duracion SF4 activo			
	SUM(DurationSF22andSF42) as sumDurationSF22andSF42,		-- duracion 2*SF4+2*SF2
	SUM(isnull(DurationSF42,0)+ isnull(DurationSF22,0)+ isnull(DurationSF4,0)+ isnull(DurationSF22andSF42,0)) as sumDurationALL
into _tSF	
from HSUPASpreadingFactor
where testId > @maxTestid	
group by testid, sessionid	

---------------- 
exec sp_lcc_dropifexists '_SF'			
select 
	tes.SessionId, hsu.TestId, 
	1.0 * hsu.sumDurationSF42 / NULLIF(hsu.sumDurationALL, 0) * 100 as PercentSF42,
	1.0 * hsu.sumDurationSF22 / NULLIF(hsu.sumDurationALL, 0) * 100 as PercentSF22,
	1.0 * hsu.sumDurationSF4 / NULLIF(hsu.sumDurationALL, 0) * 100 as PercentSF4,
	1.0 * hsu.sumDurationSF22andSF42 / NULLIF(hsu.sumDurationALL, 0) * 100 as PercentSF22andSF42
into _SF
from
	_tSF hsu, TestInfo tes 
where
	tes.TestId = hsu.TestId	and tes.SessionId=hsu.SessionId

------------------------------ (10) SHO 3G	------------------------------	
--select 'Se crean las tablas intermedias: (10) SHO 3G' info			
----------------
exec sp_lcc_dropifexists '_SHOs'			
select  
	sessionid, testid,
	1.0*(SUM(case when (HoStatus like '%Active Set Update%' Or HoStatus like '%ActiveSetUpdate%') then 1 else 0 end)
		/SUM(1)) as 'percSHO'
into _SHOs
from HandoverInfo
where testId > @maxTestid	
group by SessionId, TestId

------------------------------ (11) UL Interferences 3G------------------------------
--select 'Se crean las tablas intermedias: (11) UL Interferences 3G' info			
----------------
exec sp_lcc_dropifexists '_UL_Int'			
select sessionid, testid,
	nullif(avg (cast (dbo.SQUMTSKeyValue(Msg, LogChanType, msgType,'ul_Interference') as float)),0) as UL_Interference
into _UL_Int
from WCDMARRCMessages
where msgType like 'SysInfoType7' 
	and TestId > @maxTestid
group by sessionid, testid

------------------------------ (12)	TABLAS INTERMEDIAS RRC State para Latencias:  En TEORIA no lo piden desde GLOBAL ------------------------------
--select 'Se crean las tablas intermedias: (12)	TABLAS INTERMEDIAS RRC State para Latencias' info	
----------------
exec sp_lcc_dropifexists '_tempStateRCC'		
select SessionId, MsgTime, RRCState, 
	case when RRCState =0 then	'Disconnected'
		when RRCState = 1 then	'Connecting'
		when RRCState = 2 then	'CELL FACH'
		when RRCState = 3 then	'CELL DCH'
		when RRCState = 4 then	'CELL PCH'
		when RRCState = 5 then	'URA PCH'
	end as 'RRCState_Desc',
	ROW_NUMBER() over (PARTITION by SessionId order by MsgTime) as id
into _tempStateRCC
from WCDMARRCState
where SessionId >= @minSessionid

----------------
exec sp_lcc_dropifexists '_stateRCC'		
select ini.SessionId, ini.MsgTime as time_ini,
	isnull(fin.MsgTime,DATEADD(ms, s.duration ,s.startTime)) as time_fin, ini.RRCState, 
	ini.RRCState_Desc, ini.id
into _stateRCC
from _tempStateRCC ini 
	inner join sessions s
	on (ini.sessionid = s.sessionid)
	left join _tempStateRCC fin
	on (ini.sessionid = fin.sessionid
		and ini.id = fin.id -1)
order by 1, 2


------------------------------ (13) Throughput, Data Transferred, BLER RLC	3G ------------------------------
--select 'Se crean las tablas intermedias: (13) Throughput, Data Transferred, BLER RLC 3G' info	
----------------
exec sp_lcc_dropifexists '_THPUT_RLC'			
select 	
	t.SessionId, t.TestId, 
	Avg(t.DLThrpt) as 'AvgRLCDLThrpt',		max(t.DLThrpt) as 'maxRLCDLThrpt',
	Sum(t.DLkbit) as 'SumRLCDLkbit',		Avg(t.ULThrpt) as 'AvgRLCULThrpt',
	max(t.ULThrpt) as 'maxRLCULThrpt',		Sum(t.ULkbit) as 'SumRLCULkbit',
	AVG(t.ULBLER_RLC) as 'AvgRLCULBLER',	AVG(t.DLBLER_RLC) as 'AvgRLCDLBLER' 
	 
into _THPUT_RLC	
from 
	(Select
		s.SessionId, s.TestId, s.MsgTime, s.PosId, s.NetworkId,
		Case when s.Direction=1 Then s.SDUThPut else NULL end as ULThrpt,
		Case when s.Direction=0 Then s.SDUThPut else NULL end as DLThrpt,
		s.duration,s.Direction,
		Case when s.Direction=1 Then s.numSDUBytes*0.008 else NULL end as ULkbit,
		Case when s.Direction=0 Then s.numSDUBytes*0.008 else NULL end as DLkbit,
		numPDUGood, numPDUError, numPDUNAK,
		Case when s.Direction=1 Then
			case when (numPDUGood+numPDUError)>0 then (1.0*numPDUError/(numPDUGood+numPDUError)) else null end 
		end as ULBLER_RLC,
		Case when s.Direction=0 Then
			case when (numPDUGood+numPDUError)>0 then (1.0*numPDUError/(numPDUGood+numPDUError)) else null end 
		end as DLBLER_RLC
		
	From
		WCDMARLCStatistics s
	where s.testId > @maxTestid
	) t 
group by t.SessionId, t.TestId
order by t.SessionId, t.TestId


------------------------------ (14) Throughput Fisico, Data Transferred, Transer Time, Errores, Host, Fixed Duration 4G/3G	------------------------------
--select 'Se crean las tablas intermedias: (14) Throughput Fisico, Data Transferred, Transer Time, Errores, Host, Fixed Duration 4G/3G' info	
----------------
exec sp_lcc_dropifexists '_THPUT'			
select 
	ph.Direction,
	ph.sessionid, ph.testid, 
	AVG(8.0*ph.Throughput)  as avgThput_kbps,		max(8.0*ph.Throughput)  as maxThput_kbps,	min(8.0*ph.Throughput)  as minThput_kbps,
	MAX(ph.BytesTransferred*8.0) as 'DataTransferred',		-- es la suma de las carriers
	AVG((ph.BytesTransferred*8.0)/NULLIF(8000.0*ph.Throughput,0)) as 'TransferTime',	-- es la media de las carriers
	e.ErrorCode as 'ErrorCode',	e.msg as 'ErrorMsg', e.RemoteFilename, e.LocalFilename, e.operation, e.host,	e.FixedDuration,
	
	-- PCC:
	AVG(8.0*ph.Throughput_PCC)  as avgThput_kbps_PCC,	max(8.0*ph.Throughput_PCC)  as maxThput_kbps_PCC,	min(8.0*ph.Throughput_PCC)  as minThput_kbps_PCC,
	sum(ph.BytesTransferred_PCC*8.0) as 'DataTransferred_PCC', 
	AVG((ph.BytesTransferred_PCC*8.0)/NULLIF(8000.0*ph.Throughput_PCC,0)) as 'TransferTime_PCC',
	
	-- SCC1:
	AVG(8.0*ph.Throughput_SCC1)  as avgThput_kbps_SCC1,	max(8.0*ph.Throughput_SCC1)  as maxThput_kbps_SCC1,	min(8.0*ph.Throughput_SCC1)  as minThput_kbps_SCC1,
	sum(ph.BytesTransferred_SCC1*8.0) as 'DataTransferred_SCC1', 
	AVG((ph.BytesTransferred_SCC1*8.0)/NULLIF(8000.0*ph.Throughput_SCC1,0)) as 'TransferTime_SCC1'	
into _THPUT
from lcc_Physical_Info_Table ph
	LEFT OUTER JOIN
		(select r.sessionid, r.testid, r.ErrorCode, e.*, tp.RemoteFilename, tp.LocalFilename, tp.operation, tp.host, tp.FixedDuration
			from ResultsHTTPTransferTest r
				LEFT OUTER JOIN ResultsHTTPTransferParameters tp on (r.TestId=tp.TestId and r.SessionId=tp.SessionId)
				LEFT OUTER JOIN ErrorCodes e on (e.code = r.ErrorCode)
			where LastBlock=1	-- cogemos el ultimo bloque ya que es el que contiene la info del final de test	
				and r.testId > @maxTestid
		) e on e.SessionId=ph.sessionid and e.TestId=ph.testid
where ph.testid > @maxTestid	

group by ph.Direction, ph.sessionid, ph.testid, 
		e.ErrorCode, e.msg, e.RemoteFilename, e.LocalFilename, 
		e.operation, e.host, e.FixedDuration


------------------------------ (15)	Nuevo cálcuco IP Access Service ------------------------------
--select 'Se crean las tablas intermedias: (15)	Calculo IP Access Service' info	
-- Para el KPIID 10401/02
--	El tiempo de acceso, se calcula de forma manual - CR creado a tal efecto.
--	Issue: 470007 

----------------
-- CREAMOS LA TABLA CON TODOS LOS GETs Y PUTs, DL Y UL , NC Y CE 
exec sp_lcc_dropifexists '_lcc_gets'
select 
	testid as 'testid_get',msgtime as 'msgtime_get',protocol as 'protocol_get', 
	msg as 'msg_get',src as 'src_get',dst as 'dst_get'
into _lcc_gets
from [dbo].[MsgEthereal]
where (msg like '%GET /%/[3-5]%m% HTTP/1.1%' or msg like '%GET /[0-9]% HTTP/1.1%'
	OR msg like '%PUT /%/[1-5]%m% HTTP/1.1%' or msg like '%PUT /[0-9]% HTTP/1.1%' )
	and testId > @maxTestid	
group by testid, msgtime,protocol, msg,src,dst

----------------
-- CREAMOS LA TABLA CON TODOS LOS 200 OK PARA DOWNLINK
exec sp_lcc_dropifexists '_lcc_200'
select 
	testid as 'testid_200',msgtime as 'msgtime_200',protocol as 'protocol_200',
	msg as 'msg_200',src as 'src_200',dst as 'dst_200'
       --row_number() over(partition by testid order by msg, msgtime desc) as 'id_200'
into _lcc_200
from [dbo].[MsgEthereal] 
where msg like '%200 OK%'
	and testId > @maxTestid	
group by testid, msgtime,protocol, msg,src,dst

----------------
-- TABLA RELACIÓN 80 SYN CON 200 OK DL/ 80 SYN CON PUT UL 
exec sp_lcc_dropifexists '_lcc_ip_service'
Select 
	testid_get,msgtime_get,protocol_get,msg_get,src_get,dst_get,Ip_Service,
	id_dif
into _lcc_ip_service
from
	(select t.*,m.testid as 'testid_80', m.msgtime as 'MsgTime_80',
		m.protocol as 'protocol_80',m.msg as 'msg_80', m.src as 'src_80',
		m.dst as 'dst_80',
		Datediff(ms,m.msgtime,t.msgtime_200) as 'Ip_Service',                --DIFERENCIA DE TIEMPO ENTRE 80 SYN Y 200OK
		row_number() over(partition by m.testid order by Datediff(ms,m.msgtime,t.msgtime_200) desc) as 'id_dif'		-- La ordenacion es DESC para quedarnos con el primer 80 SYN del terminal, el mas alejado del 200OK
	from [dbo].[MsgEthereal] m 
	left outer join 
		(select *
		from(
			select *, 
				row_number() over(partition by g.testid_get order by Datediff(ms,g.msgtime_get,l.msgtime_200) asc) -- La ordenación es ascendente para quedarnos con el 200OK más cercano al GET
				 as 'id_dif_200',                                           --Ordenamos según la diferencia de tiempo entre el get y el 200 ok
				Datediff(ms,g.msgtime_get,l.msgtime_200) as 'dif_tiempo'
			from _lcc_gets g left outer join _lcc_200 l on (g.src_get = l.dst_200 and g.dst_get = l.src_200)
		where g.testid_get = l.testid_200) k

	where k.id_dif_200 = 1) t on (t.src_200 = m.dst and t.dst_200=m.src)
	where m.msg like '%80%[[SYN]]%' and t.testid_200 = m.testid and t.msgtime_get > = m.msgtime) th
where th.id_dif = 1 

union all

select 
	testid_get,msgtime_get,protocol_get,msg_get,src_get,dst_get, Ip_Service,
	id_dif_80
from (
	Select *, Datediff(ms,m.msgtime,l.msgtime_get) as 'Ip_Service',
		row_number() over(partition by m.testid order by Datediff(ms,m.msgtime,l.msgtime_get) desc) as 'id_dif_80'			-- La ordenacion es DESC para quedarnos con el primer 80 SYN del terminal, el mas alejado del 200OK
	from  [dbo].[MsgEthereal] m 
				left outer join _lcc_gets l on (l.src_get=m.src and l.dst_get = m.dst)
	where m.msg like '%80%[[SYN]]%' and l.msgtime_get > = m.msgtime and l.msg_get like '%put%' and
	m.testid = l.testid_get) u

where u.id_dif_80 = 1 


------------------------------ (16) Throughput, Bytes Transferred, Errors y Times 4G/3G - HTTP TRANSFER ------------------------------
--select 'Se crean las tablas intermedias: (16) Throughput, Bytes Transferred, Errors y Times 4G/3G - HTTP TRANSFER' info	
----------------
-- Forma antigua de calcular las cosas sin KPIID:
--	- Se calcula para mantener las columnas de _nu ya que los test fallidos pierden la info correspondiente y puede interesar saber los resultados
--	- No se realizaran los UPDATES antiguos
exec sp_lcc_dropifexists '_THPUT_Transf'			
select 	
	tt.SessionId, tt.TestId, tt.PosId, tt.NetworkId,			
	NULLIF(tt.BytesTransferred, 0) as 'DataTransferred_nu',	

	NULLIF(tt.Duration*0.001, 0) as 'SessionTime_nu',	-- hay que añadirle el tomepo del DNS, se hace despues de quedarnos con los valores validos	

	-- @FLA: se añaden case para evitar ipaccesstime mayores que el sessiontime	
	case when ISNULL(ipt.Ip_Service*0.001,0)<	ISNULL(tt.Duration*0.001,0)  then	
	    NULLIF(ISNULL(tt.Duration*0.001,0) - ISNULL(ipt.Ip_Service*0.001,0), 0)  
	else NULLIF(ISNULL(tt.Duration*0.001,0), 0) end	as'TransferTime_nu',	

	case when ISNULL(ipt.Ip_Service*0.001,0)<	ISNULL(tt.Duration*0.001,0)  then		
	    NULLIF(tt.BytesTransferred*0.008, 0) / NULLIF(ISNULL(tt.Duration*0.001,0) - ISNULL(ipt.Ip_Service*0.001,0), 0) 						
	else NULLIF(tt.BytesTransferred*0.008, 0) / NULLIF(ISNULL(tt.Duration*0.001,0), 0) 	end as 'ThputApp_nu',						
					
	NULLIF(ipt.Ip_Service*0.001, 0) as 'IPAccessTime_nu'						

into _THPUT_Transf
From ResultsHTTPTransferTest tt 
		LEFT OUTER JOIN _lcc_ip_service ipt on (ipt.Testid_get = tt.Testid)

where tt.testId > @maxTestid and
	tt.lastBlock=1	
	


--********************************************************************************************************************
--***************************************** Nuevos calculos basados en KPIID *****************************************
--********************************************************************************************************************

------------------------------ (17)	TABLA INTERMEDIA Youtube a partir de la vista de SQ  ------------------------------
select 'Se crean las tablas intermedias:  (17)	TABLA INTERMEDIA Youtube' info	
----------------
-- Se ha añadido un nuevo KPI para completar el calculo del B2

--declare @Player_Access_Timeout as int = 10
--declare @Player_Download_Timeout as int = 10 
--declare @Video_Access_Timeout as int = 10
--declare @Video_Reproduction_Timeout as int = 23
--declare @Player_IPServiceAccess_Time as int = 10620
--declare @Video_Transfer as int = 20621
--declare @min_Interrupt_Duration = 300

exec sp_lcc_dropifexists '_ETSIYouTubeKPIs'
select
	v.sessionid, v.testid, 
	v.[Image Resolution],
	v.[IP Service Access],
	v.[IP Service Access Time [s]]],
	r.msgtime as 'Block Time',  --Tiempo de bloqueo para los fallos en el acceso
	v.[Video Play Start Time [s]]] as 'Time To First Image [s]',
	v.[Minimum freeze duration [ms]]],
	v.[Maximum duration of single freeze [s]]],
	v.[Maximum duration of all freezes [s]]],
	v.[Maximum number of freezes],

	v.[Video Freeze Occurrences] as [Video Freeze Occurrences > 120ms],
	ISNULL(f.NumFreezings_300,0) as [Video Freeze Occurrences > 300ms],		-- Este es el nuestro

	v.[Video Freezing Impairment] as [Video Freezing Impairment > 120ms],
	case when ISNULL(f.NumFreezings_300,0)>0 then 'Freezings' 
		else 'No Freezings' end as [Video Freezing Impairment > 300ms],		-- Este es el nuestro
		
	v.[Accumulated Video Freezing Duration [s]]] as [Accumulated Video Freezing Duration [s]] > 120ms],
	0.001*f.AccFreezingTime_300 as [Accumulated Video Freezing Duration [s]] > 300ms],

	v.[Video Maximum Freezing Duration [s]]] as [Video Maximum Freezing Duration [s]] > 120ms],
	0.001*f.MaxFreezingTime_300 as [Video Maximum Freezing Duration [s]] > 300ms],

	0.001*f.AvgFreezingTime_300 as [Video Average Freezing Duration [s]] > 300ms],

	v.[Video Freezing Time Proportion [%]]] as [Video Freezing Time Proportion [%]] as >120ms],
	null as [Video Freezing Time Proportion [%]] as >300ms],

	--DGP 16/03/2016: Se cambia la forma de calcular los campos para tener en cuenta como fallo los nulls
	-- Clasificacion de los posibles fallos
	case when (ytbPlayer.Access = 'Failed' or ytbPlayer.Access is null) then 'Player Access Failed' else
			 case when ytbPlayer.AccessDuration > @Player_Access_Timeout then 'Player Access Timeout exceeded' else
				  case when (ytbPlayer.Download = 'Failed' or ytbPlayer.Download is null) then 'Player Download Failed' else
					   case when ytbPlayer.DownloadDuration > @Player_Download_Timeout then 'Player Download Timeout exceeded' else
					        case when (ytbVideoPlay.Access = 'Failed' or ytbVideoPlay.Access is null) then 'Video Access Failed' else
								case when ytbVideoPlay.AccessDuration > @Video_Access_Timeout then 'Video Access Timeout exceeded' else
									case when (ytbVideoPlay.Reproduction = 'Failed' or ytbVideoPlay.Reproduction is null) then 'Video Reproduction Failed' else
										case when ytbVideoPlay.ReproductionDelay > @Video_Reproduction_Timeout then 'Video Reproduction Timeout exceeded' else
												 'Successful' end
										end
								  end
							 end
						end
				  end
			 end
		end  as 'status_B1',

		kpi10620.StartTime as 'StartIPserviceAccess',
		ytbPlayer.AccessDuration as 'Duration10620',		--Player IP Service Access Time
		ytbPlayer.DownloadDuration as 'Duration20620',		--Player Download Time

		--Del KPI 20620 al KPI10621 hay un salto de tiempo que recuperamos con el KPI10625
		v.[IP Service Access Time [s]]] as 'Duration10625',		--IP Service Access Time
		ytbVideoPlay.ReproductionDelay as 'Duration30621',		--Video Reproduction start Delay

		--Video PlayOut Duration: Desde el Start of Video Transfer hasta el final (End of vedo playback)
		kpi20621.Duration as 'Duration20621',

		--DGP 16/03/2016: Se cambia la forma de calcular los campos para tener en cuenta como fallo los nulls
		--case when isnull(kpi20621.ErrorCode,0)=0 then 'Successful' else 'Failed'  end as 'status20621'
		case when (kpi20621.ErrorCode <> 0 or kpi20621.ErrorCode is null) then 'Failed' else 'Successful'  end as 'status20621'

into _ETSIYouTubeKPIs
from testinfo t, vETSIYouTubeKPIs v
		-- Tabla ResultsVideoStream, tiene el momento del Fail - Block Time
		LEFT OUTER JOIN ResultsVideoStream r on (v.TestId=r.TestId and v.sessionid=r.SessionId)
		
		-- En la vista de SQ, el tiempo minimo para las interrupciones es de 120ms, cuando nos piden 300ms:
		LEFT OUTER JOIN (Select sessionid, testid, 
							sum(case when duration>= @min_Interrupt_Duration then 1 else 0 end) as NumFreezings_300,
							avg(case when duration>= @min_Interrupt_Duration then Duration*1.0 else null end)  as AvgFreezingTime_300,
							max(case when duration>= @min_Interrupt_Duration then Duration*1.0 else null end)  as MaxFreezingTime_300,
							sum(case when duration>= @min_Interrupt_Duration then Duration*1.0 else 0 end)  as AccFreezingTime_300
						 from  ResultsVQFreezings group by sessionid, testid) f on v.sessionid=f.sessionid and v.TestId=f.TestId 
		LEFT OUTER JOIN vETSIYouTubePlayer ytbPlayer	on (v.SessionId=ytbPlayer.SessionId and v.TestId=ytbPlayer.testid)
		LEFT OUTER JOIN vETSIYouTubeStream ytbVideoPlay	on (v.SessionId=ytbVideoPlay.SessionId and v.TestId=ytbVideoPlay.testid)
		LEFT OUTER JOIN vResultsKPI kpi10620 on (v.TestId = kpi10620.TestId and kpi10620.KPIId = @Player_IPServiceAccess_Time)
		LEFT OUTER JOIN vResultsKPI kpi20621 on (v.TestId = kpi20621.TestId and kpi20621.KPIId = @Video_Transfer)

where	v.TestId > @maxTestid and
	t.testid=v.testid and t.valid=1 


------------------------------ (18)	TABLA INTERMEDIA Results KPI ------------------------------
select 'Se crean las tablas intermedias:   (18)	TABLA INTERMEDIA Results KPI' info	
----------------
--declare @Downlink_Accessibility as int = 10401
--declare @Downlink_Retainability as int = 20415
--declare @Downlink_Throughput_D1 as int = 30415

--declare @Uplink_Accessibility as int = 10402
--declare @Uplink_Retainability as int = 20416
--declare @Uplink_Throughput_D3 as int = 30416

--declare @Downlink_NC_Accessibility as int = 10401
--declare @Downlink_NC_Retainability as int = 20417
--declare @Downlink_NC_MeanDataUserRate as int = 30417

--declare @Uplink_NC_Accessibility as int = 10402
--declare @Uplink_NC_Retainability as int = 20412
--declare @Uplink_NC_MeanDataUserRate as int = 30412

--declare @Latency as int = 21000
--declare @Browser_Accessibility as int = 10400
--declare @Browser_Retainability as int = 20405
--declare @Browser_TCP_Thput as int  = 30405
--declare @Browser_SessionTime as int = 10410
--declare @DNSTime as int = 31100

exec sp_lcc_dropifexists '_lcc_ResultsKPI'
select	r.* , e.*, 
		tp.Operation, tp.protocol, tp.Host, tp.LocalFilename, tp.RemoteFilename, tp.BufferSize, tp.FixedDuration,
		tt.msg as transferMSG, br.msg as browserMSG
into _lcc_ResultsKPI
from testinfo t, sessions s, filelist f,ResultsKPI r
	LEFT OUTER JOIN ErrorCodes e on (e.code = r.ErrorCode)	
	LEFT OUTER JOIN ResultsHTTPTransferParameters tp On(tp.TestId=r.TestId)
	LEFT OUTER JOIN
		(select tt.testid, m.msg 
		 from ResultsHTTPTransferTest tt
			LEFT OUTER JOIN ErrorCodes m on (m.code = tt.ErrorCode)	
		 where  tt.lastBlock=1 and tt.testId > @maxTestid
		) tt on tt.testid=r.testid	
	LEFT OUTER JOIN
		(select tt.testid, m.msg 
		 from ResultsHTTPBrowserTest tt
			LEFT OUTER JOIN ErrorCodes m on (m.code = tt.ErrorCode)	
		 where  tt.testId > @maxTestid
		) br on br.testid=r.testid	

where r.testid=t.testid and s.sessionid=t.sessionid and s.fileid=f.fileid and

	 KPIID in (@Downlink_Accessibility,	@Downlink_Retainability,	@Downlink_Throughput_D1,		-- DL:		Access, Retain, D1
				@Uplink_Accessibility,		@Uplink_Retainability,		@Uplink_Throughput_D3,			-- UL:		Access, Retain, D3

				@Downlink_NC_Accessibility, @Downlink_NC_Retainability, @Downlink_NC_MeanDataUserRate,		-- DL NC:	Access, Retain, D1
				@Uplink_NC_Accessibility,	@Uplink_NC_Retainability,	@Uplink_NC_MeanDataUserRate,		-- UL NC:	Access, Retain, D3

				@Browser_Accessibility, @Browser_Retainability, @Browser_SessionTime, @Browser_TCP_Thput, 	-- BROWSER:	Access, Retain, Session Time avg, IP Service Access Time avg, Transfer Time avg
				@DNSTime,							-- BROWSER: DNS Time

				@Latency							-- Latency
				)
	and r.testId > @maxTestid	

-- El KPIID del timepo de DNS mete duplicados/triplicados
-- Ordenamos los valores y nos vamos a quedar con el menor
exec sp_lcc_dropifexists '_lcc_ResultsKPI_DNSTime'
select ROW_NUMBER() over (partition by sessionid, testid order by duration asc) as durationID, * 
into _lcc_ResultsKPI_DNSTime
from _lcc_ResultsKPI
where kpiid=@DNSTime

-- Limpiamos la tabla _lcc_ResultsKPI
delete _lcc_ResultsKPI
where kpiid=@DNSTime

-- Actualizamos con un unico valor de DNS:
-- Se cogen solo los valores de las query de DNS por nuestro server y de youtube en todo caso, auqnue este ultimo no hace falta
insert into _lcc_ResultsKPI
select MsgId, 	SessionId, 	TestId, 	NetworkId, 	PosId, 	KPIId, 	StartTime, 	EndTime, 	Duration, 	ErrorCode, 	Sum, 	Counter, 	Value1, 	Value2, 	Value3, 	Value4, 	Value5, 	TriggerTime, 	ErrorCodeImport, 	Description, 	Options, 	errorId, 	type, 	code, 	msg, 	Operation, 	protocol, 	Host, 	LocalFilename, 	RemoteFilename, 	BufferSize, 	FixedDuration, 	transferMSG, 	browserMSG
from _lcc_ResultsKPI_DNSTime
where durationid=1 and (value3 like '%youtube%' or value4 like '%46.24.7.18%')


-- @ERC: Actualizamos el valor de SessionTime del método antiguo para incluirle el valor del DNS
update _THPUT_Transf
set sessiontime_nu=isnull(sessiontime_nu,0) + isnull(k.duration,0)
from _THPUT_Transf th, _lcc_ResultsKPI k
where th.testid=k.testid and k.kpiid=@DNSTime

------------------------------ (19) TABLA INTERMEDIAS DOWNLINK KPI SWISSQUAL ------------------------------
select 'Se crean las tablas intermedias:  (19) TABLA INTERMEDIAS DOWNLINK KPI SWISSQUAL' info	
----------------
-- Se calcula cada KPIID para cada tipo de test:
--	- Los de NC vendran fijado por el campo FIXED DURATION (permiten que el test no se de como fallido por Timeout y se guarde la info correspondiente)

--declare @Downlink_Accessibility as int = 10401
--declare @Downlink_Retainability as int = 20415
--declare @Downlink_Throughput_D1 as int = 30415
--declare @DNSHostResolution as int = 31100


--declare @Downlink_NC_Accessibility as int = 10401
--declare @Downlink_NC_Retainability as int = 20417
--declare @Downlink_NC_MeanDataUserRate as int = 30417

exec sp_lcc_dropifexists '_lcc_http_DL'
select 
	t.SessionId, t.TestId,
	case when access.operation='GET' and access.RemoteFilename like '%500%' then 'DL_NC' 
		 when access.operation='GET' and access.RemoteFilename like '%3M%' then 'DL_CE'
	else null end as TestType,

	-- Calculo manual - ISSUE abierta con Sq, sin propuesta de cambio por su parte de momento
	ipt.Ip_Service as 'IP Access Time (ms)',
	--access.Duration as 'IP Access Time (ms)',			-- el del KPIID
	
	-- Thput Info - ResultKPIs
	tcpThput.Value3 as 'DataTransferred',										-- Number of transferred bytes
	tcpThput.Duration*0.001 as 'TransferTime', 									-- Time in ms between StartTime and EndTime			
	tcpThput.value1*0.008 as 'Throughput',										-- Value1: Throughput [Bytes/sec]
	(isnull(dns.Duration,0) + isnull(ipt.Ip_Service, 0) + isnull(tcpThput.Duration, 0))/1000.0 as SessionTime,	--	en ms -> falta sumarle el DNS Time

	-- Errores KPIID:
	access.ErrorCode as access_ErrorCode,
	case when access.ErrorCode = 0   then 'Normal'
        when access.ErrorCode = 108001 then 'Rejected'
        when access.ErrorCode = 108002 then 'Failed'
        when access.ErrorCode = 108003 then 'Timeout'
        when access.ErrorCode = 108004 then 'Start Trigger missing'
        when access.ErrorCode = 108005 then 'End Trigger missing'
        when access.ErrorCode = 108006 then 'Timing mismatch'
        when access.ErrorCode = 108010 then 'No Start Trigger'
        when access.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else access.msg
    end COLLATE Latin1_General_CI_AS as access_KPICause,


	retain.ErrorCode as retain_ErrorCode,
	case when retain.ErrorCode = 0   then 'Normal'
        when retain.ErrorCode = 108001 then 'Rejected'
        when retain.ErrorCode = 108002 then 'Failed'
        when retain.ErrorCode = 108003 then 'Timeout'
        when retain.ErrorCode = 108004 then 'Start Trigger missing'
        when retain.ErrorCode = 108005 then 'End Trigger missing'
        when retain.ErrorCode = 108006 then 'Timing mismatch'
        when retain.ErrorCode = 108010 then 'No Start Trigger'
        when retain.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else retain.msg
    end COLLATE Latin1_General_CI_AS as retain_KPICause,

	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else
		case when access.ErrorCode = 0 and retain.ErrorCode <> 0 then 'Retainability'
			 when access.ErrorCode = 0 and retain.ErrorCode is null then 'Retainability'
			 when access.ErrorCode <> 0 then 'Accessibility'
			 
		end
	end as ErrorType,

	access.transferMSG,
	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else 'Error: ' + isnull(access.transferMSG,'Unknown')
	end as ErrorCause
	 		
into _lcc_http_DL
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN _lcc_ResultsKPI access on access.testid=t.testid and access.kpiid= @Downlink_Accessibility		-- Downlink - Accessibility
		LEFT OUTER JOIN _lcc_ResultsKPI retain on retain.testid=t.testid and retain.kpiid= @Downlink_Retainability		-- Downlink - Retainability
		LEFT OUTER JOIN _lcc_ResultsKPI tcpThput on tcpThput.testid=t.testid and tcpThput.kpiid= @Downlink_Throughput_D1		-- Downlink -Throughput Mean User data rate (NED KPI D1)
		LEFT OUTER JOIN _lcc_ResultsKPI dns on dns.testid=t.testid and dns.kpiid=@DNSHostResolution
		LEFT OUTER JOIN _lcc_ip_service ipt on ipt.Testid_get = t.Testid

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and access.operation='GET' and access.RemoteFilename like '%3M%'
	and t.typeoftest='HTTPTransfer' and t.direction='Downlink'
	and t.testid > @maxtestid

union all
--------------------
---- Es vez un union all:
--insert into _lcc_http_DL
select 
	t.SessionId, t.TestId,
	case when access.operation='GET' and access.RemoteFilename like '%500%' then 'DL_NC' 
		 when access.operation='GET' and access.RemoteFilename like '%3M%' then 'DL_CE'
	else null end as TestType,

	-- Calculo manual - ISSUE abierta con Sq, sin propuesta de cambio por su parte de momento
	ipt.Ip_Service as 'IP Access Time (ms)',
	--access.Duration as 'IP Access Time (ms)',		-- el del KPIID			
	
	-- Thput Info - ResultKPIs
	tcpThput.Value3 as 'DataTransferred',										-- Number of transferred bytes
	tcpThput.Duration*0.001 as 'TransferTime', 									-- Time in ms between StartTime and EndTime			
	tcpThput.value1*0.008 as 'Throughput',										-- Value1: Throughput [Bytes/sec]
	(isnull(dns.Duration,0) + isnull(ipt.Ip_Service, 0) + isnull(tcpThput.Duration, 0))/1000.0 as SessionTime,	--	en ms -> falta sumarle el DNS Time

	-- Errores KPIID:
	access.ErrorCode as access_ErrorCode,
	case when access.ErrorCode = 0   then 'Normal'
        when access.ErrorCode = 108001 then 'Rejected'
        when access.ErrorCode = 108002 then 'Failed'
        when access.ErrorCode = 108003 then 'Timeout'
        when access.ErrorCode = 108004 then 'Start Trigger missing'
        when access.ErrorCode = 108005 then 'End Trigger missing'
        when access.ErrorCode = 108006 then 'Timing mismatch'
        when access.ErrorCode = 108010 then 'No Start Trigger'
        when access.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else access.msg
    end COLLATE Latin1_General_CI_AS as access_KPICause,


	retain.ErrorCode as retain_ErrorCode,
	case when retain.ErrorCode = 0   then 'Normal'
        when retain.ErrorCode = 108001 then 'Rejected'
        when retain.ErrorCode = 108002 then 'Failed'
        when retain.ErrorCode = 108003 then 'Timeout'
        when retain.ErrorCode = 108004 then 'Start Trigger missing'
        when retain.ErrorCode = 108005 then 'End Trigger missing'
        when retain.ErrorCode = 108006 then 'Timing mismatch'
        when retain.ErrorCode = 108010 then 'No Start Trigger'
        when retain.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else retain.msg
    end COLLATE Latin1_General_CI_AS as retain_KPICause,

	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else
		case when access.ErrorCode = 0 and retain.ErrorCode <> 0 then 'Retainability'
			 when access.ErrorCode = 0 and retain.ErrorCode is null then 'Retainability'
			 when access.ErrorCode <> 0 then 'Accessibility'
			 
		end
	end as ErrorType,

	access.transferMSG,
	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else 'Error: ' + isnull(access.transferMSG,'Unknown')
	end as ErrorCause
	 		
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN _lcc_ResultsKPI access on access.testid=t.testid and access.kpiid=@Downlink_NC_Accessibility	-- Downlink NC - Accessibility
		LEFT OUTER JOIN _lcc_ResultsKPI retain on retain.testid=t.testid and retain.kpiid=@Downlink_NC_Retainability	-- Downlink NC - Retainability
		LEFT OUTER JOIN _lcc_ResultsKPI tcpThput on tcpThput.testid=t.testid and tcpThput.kpiid=@Downlink_NC_MeanDataUserRate				-- Downlink NC -Throughput Mean User data rate (NED KPI D1)
		LEFT OUTER JOIN _lcc_ResultsKPI dns on dns.testid=t.testid and dns.kpiid=@DNSHostResolution		
		LEFT OUTER JOIN _lcc_ip_service ipt on ipt.Testid_get = t.Testid

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and access.operation='GET' and access.RemoteFilename like '%500%'
	and t.typeoftest='HTTPTransfer' and t.direction='Downlink'
	and t.testid > @maxtestid


-- **************************************************************************************************
-- **************************************************************************************************
--	Como el KPIID 30415 no se calcula bien de momento, se va a utilizar el método antiguo para calcular los thput de los test OK
--	Cuando soluciones la issue, eliminar esta parte:
--		OKO!!! Borrar tambien en UL!!!
--update _lcc_http_DL
--set DataTransferred=t.DataTransferred_nu,  TransferTime=t.TransferTime_nu, Throughput=t.ThputApp_nu, [IP Access Time (ms)]=t.IPAccessTime_nu*1000.0, 
--	sessiontime=t.sessiontime_nu
--from _lcc_http_DL d, _THPUT_Transf t
--where d.TestId=t.TestId 
--	and ErrorType is null -- solo lo modificamos en los test OK
-- **************************************************************************************************
-- **************************************************************************************************

update _lcc_http_DL
set ErrorCause='Error: IP Connection Timeout', ErrorType='Accessibility', 
	DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null,  sessiontime=null
from _lcc_http_DL
where [IP Access Time (ms)]>10000
	--and ErrorType is null

----------------
-- Se anulan los test con thput bajos:
--declare @low_Thput_DL_NC as int = 128
--declare @low_Thput_DL_CE as int = 384
----------------
update _lcc_http_DL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null,  sessiontime=null,
	ErrorType='Retainability', ErrorCause='Error: Thput. Average under ' + CONVERT(varchar(256),@low_Thput_DL_NC) + 'kbps for DL NC'
where TestType like 'DL_NC'and ErrorType is null and Throughput<@low_Thput_DL_NC

----------------
-- Se anulan los test con thput bajos:
update _lcc_http_DL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null, sessiontime=null,
	ErrorType='Retainability', ErrorCause='Error: Thput. Average under ' + CONVERT(varchar(256),@low_Thput_DL_CE) + 'kbps for DL CE'
where TestType like 'DL_CE'and ErrorType is null and Throughput<@low_Thput_DL_CE

----------------
-- Se modifica la causa de Error en los test OK pero con problemas en los KPIID:
update _lcc_http_DL
set ErrorCause='Error: Start/End Time missing (at Session/Test end)'
where (access_ErrorCode<>0 and transferMSG='OK') or (retain_ErrorCode<>0 and transferMSG='OK')




------------------------------ (20) TABLA INTERMEDIAS UPLINK KPI SWISSQUAL ------------------------------
select 'Se crean las tablas intermedias:  (20) TABLA INTERMEDIAS UPLINK KPI SWISSQUAL' info	
----------------
-- Se calcula cada KPIID para cada tipo de test:
--	- Los de NC vendran fijado por el campo FIXED DURATION (permiten que el test no se de como fallido por Timeout y se guarde la info correspondiente)

--declare @Uplink_Accessibility as int = 10402
--declare @Uplink_Retainability as int = 20416
--declare @Uplink_Throughput_D3 as int = 30416
--declare @DNSTime as int = 31100

--declare @Uplink_NC_Accessibility as int = 10402
--declare @Uplink_NC_Retainability as int = 20412
--declare @Uplink_NC_MeanDataUserRate as int = 30412

exec sp_lcc_dropifexists '_lcc_http_UL'
select 
	t.SessionId, t.TestId,
	case when access.operation='PUT' and access.LocalFilename like '%500%' then 'UL_NC' 
		 when access.operation='PUT' and access.LocalFilename like '%1M%' then 'UL_CE'
	else null end as TestType,

	-- Calculo manual - ISSUE abierta con Sq, sin propuesta de cambio por su parte de momento
	ipt.Ip_Service as 'IP Access Time (ms)',
	--access.Duration as prueba,			
	
	-- Thput Info - ResultKPIs
	tcpThput.Value3 as 'DataTransferred',										-- Number of transferred bytes
	tcpThput.Duration*0.001 as 'TransferTime', 									-- Time in ms between StartTime and EndTime			
	tcpThput.value1*0.008 as 'Throughput',										-- Value1: Throughput [Bytes/sec]
	(isnull(dns.Duration,0) + isnull(ipt.Ip_Service, 0) + isnull(tcpThput.Duration, 0))/1000.0 as SessionTime,	--	en ms -> falta sumarle el DNS Time

	-- Errores KPIID:
	access.ErrorCode as access_ErrorCode,
	case when access.ErrorCode = 0   then 'Normal'
        when access.ErrorCode = 108001 then 'Rejected'
        when access.ErrorCode = 108002 then 'Failed'
        when access.ErrorCode = 108003 then 'Timeout'
        when access.ErrorCode = 108004 then 'Start Trigger missing'
        when access.ErrorCode = 108005 then 'End Trigger missing'
        when access.ErrorCode = 108006 then 'Timing mismatch'
        when access.ErrorCode = 108010 then 'No Start Trigger'
        when access.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else access.msg
    end COLLATE Latin1_General_CI_AS as access_KPICause,


	retain.ErrorCode as retain_ErrorCode,
	case when retain.ErrorCode = 0   then 'Normal'
        when retain.ErrorCode = 108001 then 'Rejected'
        when retain.ErrorCode = 108002 then 'Failed'
        when retain.ErrorCode = 108003 then 'Timeout'
        when retain.ErrorCode = 108004 then 'Start Trigger missing'
        when retain.ErrorCode = 108005 then 'End Trigger missing'
        when retain.ErrorCode = 108006 then 'Timing mismatch'
        when retain.ErrorCode = 108010 then 'No Start Trigger'
        when retain.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else retain.msg
    end COLLATE Latin1_General_CI_AS as retain_KPICause,

	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else
		case when access.ErrorCode = 0 and retain.ErrorCode <> 0 then 'Retainability'
			 when access.ErrorCode = 0 and retain.ErrorCode is null then 'Retainability'
			 when access.ErrorCode <> 0 then 'Accessibility'
			 
		end
	end as ErrorType,

	access.transferMSG,
	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else 'Error: ' + isnull(access.transferMSG,'Unknown')
	end as ErrorCause
	 		
into _lcc_http_UL
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN _lcc_ResultsKPI access on access.testid=t.testid and access.kpiid=@Uplink_Accessibility			-- Uplink - Accessibility
		LEFT OUTER JOIN _lcc_ResultsKPI retain on retain.testid=t.testid and retain.kpiid=@Uplink_Retainability			-- Uplink - Retainability
		LEFT OUTER JOIN _lcc_ResultsKPI tcpThput on tcpThput.testid=t.testid and tcpThput.kpiid=@Uplink_Throughput_D3		-- Uplink -Throughput Mean User data rate (NED KPI D1)
		LEFT OUTER JOIN _lcc_ResultsKPI dns on dns.testid=t.testid and dns.kpiid=@DNSHostResolution		
		LEFT OUTER JOIN _lcc_ip_service ipt on (ipt.Testid_get = t.Testid)

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and access.operation='PUT' and access.LocalFilename like '%1M%'
	and t.typeoftest='HTTPTransfer' and t.direction='Uplink'
	and t.testid>@maxtestid

union all
--------------------
---- Es vez un union all:
--insert into _lcc_http_UL
select 
	t.SessionId, t.TestId,
	case when access.operation='PUT' and access.LocalFilename like '%500%' then 'UL_NC' 
		 when access.operation='PUT' and access.LocalFilename like '%1M%' then 'UL_CE'
	else null end as TestType,

	-- Calculo manual - ISSUE abierta con Sq, sin propuesta de cambio por su parte de momento
	ipt.Ip_Service as 'IP Access Time (ms)',
	--access.Duration as prueba,			
	
	-- Thput Info - ResultKPIs
	tcpThput.Value3 as 'DataTransferred',										-- Number of transferred bytes
	tcpThput.Duration*0.001 as 'TransferTime', 									-- Time in ms between StartTime and EndTime			
	tcpThput.value1*0.008 as 'Throughput',										-- Value1: Throughput [Bytes/sec]
	(isnull(dns.Duration,0) + isnull(ipt.Ip_Service, 0) + isnull(tcpThput.Duration, 0))/1000.0 as SessionTime,	--	en ms -> falta sumarle el DNS Time

	-- Errores KPIID:
	access.ErrorCode as access_ErrorCode,
	case when access.ErrorCode = 0   then 'Normal'
        when access.ErrorCode = 108001 then 'Rejected'
        when access.ErrorCode = 108002 then 'Failed'
        when access.ErrorCode = 108003 then 'Timeout'
        when access.ErrorCode = 108004 then 'Start Trigger missing'
        when access.ErrorCode = 108005 then 'End Trigger missing'
        when access.ErrorCode = 108006 then 'Timing mismatch'
        when access.ErrorCode = 108010 then 'No Start Trigger'
        when access.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else access.msg
    end COLLATE Latin1_General_CI_AS as access_KPICause,


	retain.ErrorCode as retain_ErrorCode,
	case when retain.ErrorCode = 0   then 'Normal'
        when retain.ErrorCode = 108001 then 'Rejected'
        when retain.ErrorCode = 108002 then 'Failed'
        when retain.ErrorCode = 108003 then 'Timeout'
        when retain.ErrorCode = 108004 then 'Start Trigger missing'
        when retain.ErrorCode = 108005 then 'End Trigger missing'
        when retain.ErrorCode = 108006 then 'Timing mismatch'
        when retain.ErrorCode = 108010 then 'No Start Trigger'
        when retain.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else retain.msg
    end COLLATE Latin1_General_CI_AS as retain_KPICause,

	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else
		case when access.ErrorCode = 0 and retain.ErrorCode <> 0 then 'Retainability'
			 when access.ErrorCode = 0 and retain.ErrorCode is null then 'Retainability'
			 when access.ErrorCode <> 0 then 'Accessibility'
			 
		end
	end as ErrorType,

	access.transferMSG,
	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else 'Error: ' + isnull(access.transferMSG,'Unknown')
	end as ErrorCause
	 		
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN _lcc_ResultsKPI access on access.testid=t.testid and access.kpiid=@Uplink_NC_Accessibility			-- Uplink NC - Accessibility
		LEFT OUTER JOIN _lcc_ResultsKPI retain on retain.testid=t.testid and retain.kpiid=@Uplink_NC_Retainability			-- Uplink NC - Retainability
		LEFT OUTER JOIN _lcc_ResultsKPI tcpThput on tcpThput.testid=t.testid and tcpThput.kpiid=@Uplink_NC_MeanDataUserRate	-- Uplink NC - Mean User data rate 
		LEFT OUTER JOIN _lcc_ResultsKPI dns on dns.testid=t.testid and dns.kpiid=@DNSHostResolution				
		LEFT OUTER JOIN _lcc_ip_service ipt on (ipt.Testid_get = t.Testid)

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and access.operation='PUT' and access.LocalFilename like '%500%'
	and t.typeoftest='HTTPTransfer' and t.direction='Uplink'
	and t.testid>@maxtestid


-- **************************************************************************************************
-- **************************************************************************************************
--	Como el KPIID 30415 no se calcula bien de momento, se va a utilizar el método antiguo para calcular los thput de los test OK
--	Cuando soluciones la issue, eliminar esta parte:
----		OJO!!! Borrar tambien en DL!!!
--update _lcc_http_UL
--set DataTransferred=t.DataTransferred_nu,  TransferTime=t.TransferTime_nu, Throughput=t.ThputApp_nu, [IP Access Time (ms)]=t.IPAccessTime_nu*1000.0, sessiontime=t.sessiontime_nu
--from _lcc_http_UL d, _THPUT_Transf t
--where d.TestId=t.TestId 
--	and d.ErrorType is null -- solo lo modificamos en los test OK
-- **************************************************************************************************
-- **************************************************************************************************

update _lcc_http_UL
set ErrorCause='Error: IP Connection Timeout', ErrorType='Accessibility', 
	DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null,  sessiontime=null
from _lcc_http_UL
where [IP Access Time (ms)]>10000
	--and ErrorType is null

----------------
-- Se anulan los test con thput bajos:
--declare @low_Thput_UL_NC as int = 64
--declare @low_Thput_UL_CE as int = 384

update _lcc_http_UL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null, sessiontime=null,
	ErrorType='Retainability', ErrorCause='Error: Thput. Average under ' + CONVERT(varchar(256),@low_Thput_UL_NC) + 'kbps for UL NC'
where TestType like 'UL_NC'and ErrorType is null and Throughput<@low_Thput_UL_NC	

----------------
-- Se anulan los test con thput bajos:
update _lcc_http_UL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null,sessiontime=null,
	ErrorType='Retainability', ErrorCause='Error: Thput. Average under ' + CONVERT(varchar(256),@low_Thput_UL_CE) + 'kbps for CE'
where TestType like '%_CE'and ErrorType is null and Throughput<@low_Thput_UL_CE

----------------
-- Se modifica la causa de Error en los test OK pero con problemas en los KPIID:
update _lcc_http_UL
set ErrorCause='Error: Start/End Time missing (at Session/Test end)'
where (access_ErrorCode<>0 and transferMSG='OK') or (retain_ErrorCode<>0 and transferMSG='OK')



------------------------------ (21) TABLA INTERMEDIAS BROWSING KPI SWISSQUAL ------------------------------
select 'Se crean las tablas intermedias:  (21) TABLA INTERMEDIAS BROWSING KPI SWISSQUAL' info	
----------------
---- Se calcula cada KPIID para cada tipo de test:
--declare @Browser_Accessibility as int = 10400
--declare @Browser_Retainability as int = 20405
--declare @Browser_TCP_Thput as int  = 30405
--declare @Browser_SessionTime as int = 10410
--declare @DNSTime as int = 31100

exec sp_lcc_dropifexists '_lcc_http_browser'
select 
	t.SessionId, t.TestId, 

	--Type TEST - ResultKPIs
	case when access.value5 like '%//kepler.%' then 'Kepler 0s Pause'
		 when access.value5 like '%//kepler2.%' then 'Kepler 30s Pause'
		 when access.value5 like '%//mkepler.%' then 'Mobile Kepler 0s Pause' 
		 when access.value5 like '%//mkepler2.%' then 'Mobile Kepler 30s Pause' 
		 when access.value5 like '%m.ebay.es%' Then 'Ebay'
		 when access.value5 like '%google.es%' Then 'Google'
		 when access.value5 like '%elpais.com%' Then 'El Pais'
		 when access.value5 like '%youtube.com%' Then 'Youtube'
	 else null end  as TestType,

	-- Thput Info - ResultKPIs
	tcpThput.Value3 as DataTransferred,			-- Size of file
	tcpThput.Value1*0.008 as Throughput,		-- Throughput [Bytes/sec]

	-- Times Info - ResultKPIs:
	access.Duration as 'IPAccessT',
	retain.Duration as 'transferT',
	sessionT.Duration + isnull(dns.Duration,0) as 'sessionT',		-- salen mas de un valor en algunos test ¿?
	dns.Duration as DNST,

	-- Sin anular:
	tcpThput.Value3 as DataTransferred_nu,			-- Size of file
	tcpThput.Value1*0.008 as ThputApp_nu,			-- Throughput [Bytes/sec]
	access.Duration as 'IPAccessTime_nu',
	retain.Duration as 'TransferTime_nu',
	sessionT.Duration + isnull(dns.Duration,0) as 'SessionTime_nu',		
	dns.Duration as DNSTime_nu,

	-- Errores KPIID:
	access.ErrorCode as access_ErrorCode,
	case when access.ErrorCode = 0   then 'Normal'
        when access.ErrorCode = 108001 then 'Rejected'
        when access.ErrorCode = 108002 then 'Failed'
        when access.ErrorCode = 108003 then 'Timeout'
        when access.ErrorCode = 108004 then 'Start Trigger missing'
        when access.ErrorCode = 108005 then 'End Trigger missing'
        when access.ErrorCode = 108006 then 'Timing mismatch'
        when access.ErrorCode = 108010 then 'No Start Trigger'
        when access.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else access.msg
    end COLLATE Latin1_General_CI_AS as access_KPICause,

	retain.ErrorCode as retain_ErrorCode,
	case when retain.ErrorCode = 0   then 'Normal'
        when retain.ErrorCode = 108001 then 'Rejected'
        when retain.ErrorCode = 108002 then 'Failed'
        when retain.ErrorCode = 108003 then 'Timeout'
        when retain.ErrorCode = 108004 then 'Start Trigger missing'
        when retain.ErrorCode = 108005 then 'End Trigger missing'
        when retain.ErrorCode = 108006 then 'Timing mismatch'
        when retain.ErrorCode = 108010 then 'No Start Trigger'
        when retain.ErrorCode = 108015 then 'End Trigger missing (Test unsuccessful)'
    -- all others
    else retain.msg
    end COLLATE Latin1_General_CI_AS as retain_KPICause,

	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else
		case when access.ErrorCode = 0 and retain.ErrorCode <> 0 then 'Retainability'
			 when access.ErrorCode = 0 and retain.ErrorCode is null then 'Retainability'
			 when access.ErrorCode <> 0 then 'Accessibility'
			 
		end
	end as ErrorType,

	access.browserMSG,
	case when access.ErrorCode = 0 and retain.ErrorCode = 0 then null
	else 'Error: ' + isnull(access.browserMSG,'Unknown')
	end as ErrorCause

into _lcc_http_browser
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN _lcc_ResultsKPI access on access.testid=t.testid and access.kpiid=@Browser_Accessibility		-- Browser - Accessibility
		LEFT OUTER JOIN _lcc_ResultsKPI retain on retain.testid=t.testid and retain.kpiid=@Browser_Retainability		-- Browser - Retainability
		LEFT OUTER JOIN _lcc_ResultsKPI sessionT on sessionT.testid=t.testid and sessionT.kpiid=@Browser_SessionTime	-- Browser - Session Time avg	
		LEFT OUTER JOIN _lcc_ResultsKPI dns on dns.testid=t.testid and dns.kpiid=@DNSTime						-- Browser - DNS Time								
		LEFT OUTER JOIN _lcc_ResultsKPI tcpThput on tcpThput.testid=t.testid and tcpThput.kpiid=@Browser_TCP_Thput		-- Browser - TCP Throughput			

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and t.typeoftest='HTTPBrowser' 
	and t.testid>@maxtestid

order by t.startTime


----------------	
-- Se anulan los test que duren mas de 10s - se supone que lo hace la herramienta pero no es así y los de por validos
--declare @Browser_Transfer_Timeout as int = 10000
--declare @Browser_IP_Connection_Timeout as int = 10000

----------------
-- Se anulan los test que duren mas de 10s - se supone que lo hace la herramienta pero no es así
update _lcc_http_browser
set ErrorCause='Error: IP Connection Timeout', ErrorType='Accessibility', Throughput=null, DataTransferred=null,
	sessionT=null, IPAccessT=null, transferT=null
where [IPAccessT]>@Browser_IP_Connection_Timeout
	--and ErrorType is null

update _lcc_http_browser
set ErrorCause='Error: Transfer Timeout', ErrorType='Retainability', Throughput=null, DataTransferred=null,
	sessionT=null, IPAccessT=null, transferT=null
where (transferT>@Browser_Transfer_Timeout or sessionT>@Browser_Transfer_Timeout)
	--and ErrorType is null



----------------
-- Se modifica la causa de Error en los test OK pero con problemas en los KPIID:
update _lcc_http_browser
set ErrorCause='Error: Start/End Time missing (at Session/Test end)'
where (access_ErrorCode<>0 and browserMSG='OK') or (retain_ErrorCode<>0 and browserMSG='OK')



------------------------------ (22) TABLA INTERMEDIAS LATENCIAS KPI SWISSQUAL ------------------------------
select 'Se crean las tablas intermedias:  (22) TABLA INTERMEDIAS LATENCIAS KPI SWISSQUAL' info	
---------------- 
-- Se calcula cada KPIID para cada tipo de test
-- Esta pendiente lo de contar solo con los PING en CELL DCH -> cuando se de por bueno el nuevo job con más tiempo de IDLE
--declare @Latency as int = 21000
--declare @sizePing as int = 32

exec sp_lcc_dropifexists '_lcc_http_latencias'
select 
	t.SessionId, t.TestId, ping.Duration, ping.size
into _lcc_http_latencias
from
	filelist f, sessions s, testinfo t
		LEFT OUTER JOIN 
			(
			select p.TestId, p.Duration, s.RRCState, s.RRCState_Desc, p.value2 as size,
					ROW_NUMBER() over (PARTITION by p.TestId order by p.Duration) as y,	
					count(p.Duration) over (PARTITION by p.TestId) as num_ping		
			from _lcc_ResultsKPI p 
						left join _stateRCC s on (p.SessionId = s.SessionId	and p.endTime between s.time_ini and s.time_fin)
			where p.kpiid=@Latency and p.value2=@sizePing and p.errorCode=0	
				and (s.RRCState_Desc is null or s.RRCState_Desc = 'CELL DCH')	
			) ping on ping.testid=t.testid

where t.sessionid=s.sessionid and s.FileId=f.fileid
	and t.typeoftest='Ping'
	and ping.y = case when num_ping = 5 then 3
				 when num_ping = 4 then 2 --La más baja de las medianas centrales
				 when num_ping = 3 then 2
				 when num_ping = 2 then 1 --La más baja de las medianas centrales
				 when num_ping = 1 then 1
				 end
	and ping.size=@sizePing
	and t.testid>@maxtestid

--exec sp_lcc_dropifexists '_lcc_http_latencias'

--select  p.sessionid,
--		p.testid,
--		p.Duration,
--		p.Size

--into _lcc_http_latencias
--from
--	(select 
--		t.SessionId, 
--		t.TestId, 
--		percentile_cont(0.5)
--		within group (order by ping.duration)
--		over (partition by t.sessionid, t.testid) as Duration, 
--		ping.size
	
--	from
--		filelist f, sessions s, testinfo t
--			LEFT OUTER JOIN 
--				(
--				select p.TestId, p.Duration, s.RRCState, s.RRCState_Desc, p.value2 as size,
--						p.value3 as 'index', m.Maxind 		
--				from _lcc_ResultsKPI p 
--							left join _stateRCC s on (p.SessionId = s.SessionId	and p.endTime between s.time_ini and s.time_fin)
--							left join (select sessionid, testid, max(value3) as maxind from _lcc_ResultsKPI where kpiid=@Latency and value2=@sizePing and errorCode=0 group by sessionid, testid) m on (m.SessionId = s.SessionId	and m.testid=p.testid)
--				where p.kpiid=@Latency and p.value2=@sizePing and p.errorCode=0	
--					and (s.RRCState_Desc is null or s.RRCState_Desc = 'CELL DCH')	
--				) ping on ping.testid=t.testid

--	where t.sessionid=s.sessionid and s.FileId=f.fileid
--		and t.typeoftest='Ping'
--		and ping.[index] between ping.Maxind-4 and Maxind
--		and ping.size=@sizePing
--		and t.testid>@maxtestid) p

--group by p.sessionid, p.testid, p.Duration,	p.Size 



------------------------------ (23) TABLA INTERMEDIAS YOUTUBE KPI SWISSQUAL------------------------------
--select 'Se crean las tablas intermedias:  (23) TABLA INTERMEDIAS YOUTUBE KPI SWISSQUAL' info	
------------------
---- Se calcula cada KPIID para cada tipo de test
----			Añadido KPI nuevo para el calculo del B2 que no lo estabamos teniendo en cuenta hasta ahora
--exec sp_lcc_dropifexists '_lcc_http_youtube'
--select 
--	t.SessionId, t.TestId, 	
--	ytb.[Image Resolution] as 'Video Resolution',

--	--	B1 :	YouTube Service Access Success Ratio [%]  
--	case when ytb.status_B1 = 'Successful' then null else 'Failed' end as 'Fails',
--	case when ytb.status_B1 = 'Successful' then null else ytb.status_B1 end as 'Cause',
--	case when ytb.status_B1 = 'Successful' then null else
--		case when ytb.status_B1 = 'Player Access Timeout exceeded' then dateadd(ms,ytb.Duration10620*1000, ytb.StartIPserviceAccess)
--			when ytb.status_B1 = 'Player Download Timeout exceeded' then dateadd(ms, (ytb.Duration10620+ytb.Duration20620)*1000, ytb.StartIPserviceAccess)
--			when ytb.status_B1 = 'Video Access Timeout exceeded' then dateadd(ms, ytb.Duration10625*1000, ytb.StartIPserviceAccess)
--			when ytb.status_B1 = 'Video Reproduction Timeout exceeded' then dateadd(ms, (ytb.Duration10625+ytb.Duration30621)*1000, ytb.StartIPserviceAccess)
--			else ytb.[Block Time] --Si no es error por timeout, el tiempo de bloqueo será el de antes
--		end end as 'Block Time',	
	
--	-- Tiempo hasta el Start of video playback - first frame displayed in player		 
--	case when ytb.status_B1 = 'Successful' then ytb.[Time To First Image [s]]] end as '[Time To First Image [s]]]',
	
--	ytb.[Video Freeze Occurrences > 300ms] as 'Num. Interruptions',
--	ytb.[Video Freezing Impairment > 300ms],
	
--	-- B3:	distinto a los requisitos de P3:
--	ytb.[Accumulated Video Freezing Duration [s]] > 300ms] as 'Accumulated Video Freezing Duration [s]',
--	ytb.[Video Average Freezing Duration [s]] > 300ms] as 'Average Video Freezing Duration [s]',
--	ytb.[Video Maximum Freezing Duration [s]] > 300ms] as 'Maximum Video Freezing Duration [s]',
	
--	-- B2:	 B1.1 success + freezing events and Playout (status20621)
--	case when ytb.status_B1 <> 'Successful'  then 'W Interruptions'
--		else (case when ytb.[Video Freezing Impairment > 300ms]='No Freezings' and ytb.status20621='Successful' then 'W/O Interruptions' 
--				   else 'W Interruptions' end) end as 'End Status', 

--	case when  ytb.status_B1 <> 'Successful' then 'Failed' --Fallos
--		else case when ytb.status_B1 <> 'Video Access Timeout exceeded'					--Entrarían ya como fallos en el B1, pero por seguir las condiciones de la metodología
--					and ytb.status_B1 <> 'Video Reproduction Timeout exceeded'			--Entrarían ya como fallos en el B1, pero por seguir las condiciones de la metodología
--					and isnull([Video Maximum Freezing Duration [s]] > 300ms],0) <=8		--Ningún freezings de más de 8 segundos
--					and isnull([Accumulated Video Freezing Duration [s]] > 300ms],0) < 15	--Suma de todos los frezing menor a 15 segundos
--					and isnull([Video Freeze Occurrences > 300ms],0) <= 10					--No más de 10 freezings
--				then 'Successful'
--				else 'Failed'
--			end
--	end as 'Succeesful_Video_Download'

--into _lcc_http_youtube

--from
--	filelist f, sessions s, testinfo t	
--		LEFT OUTER JOIN _ETSIYouTubeKPIs ytb on (t.SessionId=ytb.SessionId and t.TestId=ytb.testid)
					
--where 
--	t.SessionId=s.SessionId and s.FileId=f.FileId
--	and t.typeoftest like '%YouTube%' 
--	and t.valid=1 and s.valid=1 
--	and t.testid>@maxtestid

--order by t.startTime


------------------------------ (24) TABLAS KPIS EXTRAS CEM SWISSQUAL------------------------------

exec sp_lcc_dropifexists '_Paging'	
--Paging
select r.sessionid,
	   r.testid,
	   1.0*sum(case when r.errorcode = 0 then 1 else 0 end)/count(r.errorcode) as Paging_Success_Ratio

into _Paging	   
from resultskpi r
where r.testid > @maxtestid

group by r.sessionid, r.testid

exec sp_lcc_dropifexists '_PDP'	
--PDP
select r.sessionid,
	   r.testid,
	   1.0*sum(case when r.errorcode = 0 then 1 else 0 end)/count(r.errorcode) as PDP_Activate_Ratio

into _PDP	   
from resultskpi r
where r.kpiid=15200
and r.testid > @maxtestid

group by r.sessionid, r.testid


exec sp_lcc_dropifexists '_NEIGH'	
-- Neighbors
select  l.sessionid,
		l.testid,
		l.EARFCN as EARFCN_PCC,
		l.PhyCellId as PCI_PCC,
		10*LOG10(AVG(POWER(CAST(10 AS float), (l.RSRP)/10.0))) as RSRP_PCC,
		10*LOG10(AVG(POWER(CAST(10 AS float), (l.RSRQ)/10.0))) as RSRQ_PCC,
		ln.EARFCN_N1,
		ln.PCI_N1,
		10*LOG10(AVG(POWER(CAST(10 AS float), (ln.RSRP_N1)/10.0))) as RSRP_N1,
		10*LOG10(AVG(POWER(CAST(10 AS float), (ln.RSRQ_N1)/10.0))) as RSRQ_N1

into _NEIGH
from LTEmeasurementReport l

left outer join 
			( select 
				ln.ltemeasreportid,
				l.msgtime,
				ln.EARFCN as EARFCN_N1,
				ln.PhyCellId as PCI_N1,
				ln.RSRP as RSRP_N1,
				ln.RSRQ as RSRQ_N1,
				ln.carrierindex,
				row_number () over (partition by l.sessionid, l.testid order by l.msgtime asc, ln.RSRP desc) as id
				
				from LTENeighbors ln, LTEmeasurementReport l, testinfo t
				where carrierindex=0 --Solo para la PCC
				and l.ltemeasreportid=ln.ltemeasreportid
				and t.sessionid=l.sessionid and l.testid=t.testid
				and l.msgtime >= dateadd(ss, -1, dateadd(ms, t.duration, t.starttime))
				and l.testid > @maxtestid
			) ln on l.ltemeasreportid=ln.ltemeasreportid and ln.id=1

where ln.EARFCN_N1 is not null

group by l.sessionid, l.testid,l.EARFCN,l.PhyCellId, ln.EARFCN_N1, ln.PCI_N1, l.msgtime
order by l.sessionid, l.testid


exec sp_lcc_dropifexists '_4GHO'	
--HO 4G/4G
select  r.sessionid,
		r.testid,
		count( r.sessionid ) as num_HO_S1X2,
		avg(r.duration) as duration_S1X2_avg,
		1.0*sum(case when (r.kpiid in (38100) and r.errorcode<>0) then 0 else 1 end)/count(r.sessionid) as S1X2HO_SR

into _4GHO
from resultskpi r
where r.kpiid in (38100)
and r.testid > @maxtestid
group by  r.sessionid, r.testid


exec sp_lcc_dropifexists '_Window'	
-- Windows Size
select  m.sessionid,
		m.testid,
		max(m.Win) as Max_Win

into _Window
from
(
		select m.sessionid,
		m.testid,
		max(cast (substring(m.msg, charindex('win=',m.msg)+4,len(m.msg)-charindex('win=',m.msg)+4) as int)) as Win

		from msgethereal m

		where m.protocol='tcp'
		and m.msg like '%win=%' and m.msg not like '%urg%'
		and m.testid > @maxtestid
		group by m.sessionid, m.testid

		) m

group by m.sessionid, m.testid

exec sp_lcc_dropifexists '_BUFFER'
-- Youtube Buffer
select 
		v.sessionid,
		v.testid,
		v.[Video IP Service Access Time [s]]] as Video_IPService_Time,
		v.[video reproduction start delay [s]]] as Buffering_Time, --KPIID: 30621
		v.[video play start time [s]]] as [Time To First Image [s]]]

into _BUFFER
from vETSIYouTubeKPIs v

where v.testid > @maxtestid


--***********************************************************************************************************************
--************************************************ INICIO TABLAS FINALES ************************************************
--***********************************************************************************************************************
select 'INICIO TABLAS FINALES' info

-- (1)
-- *****************************************
------		TABLA FINAL HTTP DL		  ------		select * from Lcc_Data_HTTPTransfer_DL -- _lcc_http_DL	
-- *****************************************
select 'Inicio creacion tabla Lcc_Data_HTTPTransfer_DL' info

insert Lcc_Data_HTTPTransfer_DL
select 
	-- Info general 
	f.CallingModule as MTU,	f.IMEI,	f.CollectionName, LEFT(f.IMSI,3) as MCC, RIGHT(LEFT(f.IMSI,5),2) as MNC, 
	t.startDate, t.startTime, DATEADD(ms, t.duration ,t.startTime) as endTime,			 	
	t.SessionId, f.FileId, t.TestId, t.typeoftest, t.direction, s.info,

	--_lcc_http_DL:
	dl_kpiid.TestType as TestType, '0' as ServiceType,	
	dl_kpiid.[IP Access Time (ms)],	dl_kpiid.DataTransferred,	dl_kpiid.TransferTime,			
	dl_kpiid.ErrorCause as ErrorCause,	dl_kpiid.ErrorType as ErrorType,		
	dl_kpiid.Throughput as Throughput,	null as Throughput_MAX,

	-- PCC:
	thput.DataTransferred_PCC as DataTransferred_PCC,		
	thput.TransferTime_PCC as TransferTime_PCC,
	thput.avgThput_kbps_PCC as Throughput_PCC,	
	thput.maxThput_kbps_PCC as Throughput_MAX_PCC,
		
	-- SCC1:	- De momento solo se calcula para la SCC1
	thput.DataTransferred_SCC1 as DataTransferred_SCC1,		
	thput.TransferTime_SCC1 as TransferTime_SCC1,
	thput.avgThput_kbps_SCC1 as Throughput_SCC1,	
	thput.maxThput_kbps_SCC1 as Throughput_MAX_SCC1,
	
	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as 'DataTransferred_SCC2', null as 'TransferTime_SCC2', null as 'Throughput_SCC2', null as 'Throughput_MAX_SCC2',	null as 'DataTransferred_SCC3', null as 'TransferTime_SCC3', null as 'Throughput_SCC3', null as 'Throughput_MAX_SCC3',
	null as 'DataTransferred_SCC4', null as 'TransferTime_SCC4', null as 'Throughput_SCC4', null as 'Throughput_MAX_SCC4',	null as 'DataTransferred_SCC5', null as 'TransferTime_SCC5', null as 'Throughput_SCC5', null as 'Throughput_MAX_SCC5',
	null as 'DataTransferred_SCC6', null as 'TransferTime_SCC6', null as 'Throughput_SCC6', null as 'Throughput_MAX_SCC6',	null as 'DataTransferred_SCC7', null as 'TransferTime_SCC7', null as 'Throughput_SCC7',	null as 'Throughput_MAX_SCC7',
	
	-- 3G:	
	thput_rlc.maxRLCDLThrpt as RLC_MAX,	

	-- Technology:		- tech info DL
	-- PCC:
	ISNULL(pctTech.pctLTE, 0) as '% LTE', 	ISNULL(pctTech.pctWCDMA, 0) as '% WCDMA',	ISNULL(pctTech.pctGSM, 0) as '% GSM',
	
	ISNULL(pctTech.pct_F1_U2100, 0) as '% F1 U2100',	ISNULL(pctTech.pct_F2_U2100, 0) as '% F2 U2100',	ISNULL(pctTech.pct_F3_U2100, 0) as '% F3 U2100',
	ISNULL(pctTech.pct_F1_U900, 0) as '% F1 U900',		ISNULL(pctTech.pct_F2_U900, 0) as '% F2 U900',
	ISNULL(pctTech.pct_F1_L2600, 0) as '% F1 L2600',	ISNULL(pctTech.pct_F1_L2100, 0) as '% F1 L2100',	ISNULL(pctTech.pct_F2_L2100, 0) as '% F2 L2100',
	ISNULL(pctTech.pct_F1_L1800, 0) as '% F1 L1800',	ISNULL(pctTech.pct_F2_L1800, 0) as '% F2 L1800',	ISNULL(pctTech.pct_F3_L1800, 0) as '% F3 L1800',
	ISNULL(pctTech.pct_F1_L800, 0) as '% F1 L800',
	
	ISNULL(pctTech.pctUMTS_2100, 0) as '% U2100',	ISNULL(pctTech.pctUMTS_900, 0) as '% U900',		ISNULL(pctTech.pctLTE_2600, 0) as '% LTE2600',
	ISNULL(pctTech.pctLTE_2100, 0) as '% LTE2100',	ISNULL(pctTech.pctLTE_1800, 0) as '% LTE1800',	ISNULL(pctTech.pctLTE_800, 0) as '% LTE800',	
	
	ISNULL(pctTech.pctGMS_DCS, 0) as 'DCS %',	ISNULL(pctTech.pctGSM_GSM, 0) as 'GSM %',	ISNULL(pctTech.pctGSM_EGSM, 0) as 'EGSM %',
	
	-- SCC1:	- De momento solo se calcula para la SCC1
	ISNULL(pctTech.pctLTE_2600_SCC1, 0) as '% LTE2600_SCC1',	ISNULL(pctTech.pctLTE_1800_SCC1, 0) as '% LTE1800_SCC1',	ISNULL(pctTech.pctLTE_800_SCC1, 0) as '% LTE800_SCC1',	

	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '% LTE2600_SCC2', null as '% LTE1800_SCC2', null as '% LTE800_SCC2',	null as '% LTE2600_SCC3', null as '% LTE1800_SCC3', null as '% LTE800_SCC3',	
	null as '% LTE2600_SCC4', null as '% LTE1800_SCC4', null as '% LTE800_SCC4',	null as '% LTE2600_SCC5', null as '% LTE1800_SCC5', null as '% LTE800_SCC5',	
	null as '% LTE2600_SCC6', null as '% LTE1800_SCC6', null as '% LTE800_SCC6',	null as '% LTE2600_SCC7', null as '% LTE1800_SCC7', null as '% LTE800_SCC7',
		
	---------------------------------			
	-- 3G:
	mod3G.Percent_QPSK as '% QPSK 3G',				
	mod3G.Percent_16QAM as '% 16QAM 3G',				
	mod3G.Percent_64QAM as '% 64QAM 3G',
		
	mod3G.Average_codes as 'Num Codes',		
	mod3G.max_codes as 'Max Codes',			
	mod3G.DualCarrier_use as '% Dual Carrier',			
	case when mod3G.DualCarrier_use > 0 then 2 else 1 end as 'Carriers',		
	
	---------------------------------
	-- 4G:			
	-- CA
	100.0*mod4G.[% QPSK] as '% QPSK 4G',	100.0*mod4G.[% 16QAM] as '% 16QAM 4G',	100.0*mod4G.[% 64QAM] as '% 64QAM 4G',

	-- PCC:
	100.0*mod4G.[% QPSK PCC] as '% QPSK 4G PCC',	100.0*mod4G.[% 16QAM PCC] as '% 16QAM 4G PCC',	100.0*mod4G.[% 64QAM PCC] as '% 64QAM 4G PCC',	

	-- SCC1:	- De momento solo se calcula para la SCC1
	100.0*mod4G.[% QPSK SCC1] as '% QPSK 4G SCC1',	100.0*mod4G.[% 16QAM SCC1] as '% 16QAM 4G SCC1',	100.0*mod4G.[% 64QAM SCC1] as '% 64QAM 4G SCC1',	
	
	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '% QPSK 4G SCC2', null as '% 16AQM 4G SCC2', null as '% 64QAM 4G SCC2',		null as '% QPSK 4G SCC3', null as '% 16AQM 4G SCC3', null as '% 64QAM 4G SCC3', 	null as '% QPSK 4G SCC4', null as '% 16AQM 4G SCC4', null as '% 64QAM 4G SCC4', 
	null as '% QPSK 4G SCC5', null as '% 16AQM 4G SCC5', null as '% 64QAM 4G SCC5',		null as '% QPSK 4G SCC6', null as '% 16AQM 4G SCC6', null as '% 64QAM 4G SCC6', 	null as '% QPSK 4G SCC7', null as '% 16AQM 4G SCC7', null as '% 64QAM 4G SCC7',		
			
	-- PCC
	pctTech.pctLTE_10Mhz as '10Mhz Bandwidth %',	pctTech.pctLTE_15Mhz as '15Mhz Bandwidth %',	pctTech.pctLTE_20Mhz as '20Mhz Bandwidth %',
	
	-- SCC1
	pctTech.pctLTE_10Mhz_SCC1 as '10Mhz Bandwidth SCC1 %',	pctTech.pctLTE_15Mhz_SCC1 as '15Mhz Bandwidth SCC1 %',	pctTech.pctLTE_20Mhz_SCC1 as '20Mhz Bandwidth SCC1 %',

	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '10Mhz Bandwidth SCC2 %', null as '15Mhz Bandwidth SCC2 %', null as '20Mhz Bandwidth SCC2 %',	null as '10Mhz Bandwidth SCC3 %', null as '15Mhz Bandwidth SCC3 %', null as '20Mhz Bandwidth SCC3 %', 	null as '10Mhz Bandwidth SCC4 %', null as '15Mhz Bandwidth SCC4 %', null as '20Mhz Bandwidth SCC4 %', 
	null as '10Mhz Bandwidth SCC5 %', null as '15Mhz Bandwidth SCC5 %', null as '20Mhz Bandwidth SCC5 %', 	null as '10Mhz Bandwidth SCC6 %', null as '15Mhz Bandwidth SCC6 %', null as '20Mhz Bandwidth SCC6 %', 	null as '10Mhz Bandwidth SCC7 %', null as '15Mhz Bandwidth SCC7 %', null as '20Mhz Bandwidth SCC7 %',	

	---------------							
	-- Performance:	
	-- 3G:
	cqi3G.CQI as 'CQI 3G',
	100.0*hs3G.hscch_use as '% SCCH',		hq.NumHarqProc_avg as 'Procesos HARQ',	
	cqi3G.avgBLER as 'BLER DSCH',			100.0*cqi3G.numDtx_DL as 'DTX DSCH',	100.0*cqi3G.NumAck_DL as 'ACKs',		100.0*cqi3G.NumNack_DL as '% NACKs',			
	mod3G.avgRateRetransmissions as 'Retrx DSCH',		'' as 'RETRX MAC',												
	thput_rlc.AvgRLCDLBLER as 'BLER RLC',	thput_rlc.AvgRLCDLThrpt as 'RLC Thput',

	-- 4G:
	rbs.Rbs_round as 'RBs',	rbs.maxRBs as 'Max RBs',	rbs.minRBs as 'Min RBs',	rbs.Rbs_dedicated_round as 'RBs When Allocated',	
	
	-- ni idea de como se coge
	tm.percTM0 as '% TM Invalid',
	tm.percTM1 as '% TM 1: Single Antenna Port 0 ',	
	tm.percTM2 as '% TM 2: TD Rank 1',	
	tm.percTM3 as '% TM 3: OL SM',
	tm.percTM4 as '% TM 4: CL SM',
	tm.percTM5 as '% TM 5: MU MIMO',	
	tm.percTM6 as '% TM 6: CL RANK1 PC',	
	tm.percTM7 as '% TM 7: Single Antenna Port 5',
	tm.percTMunknown as '% TM Unknown',    
	
	shcch4G.Percent_LTESharedChannelUse as 'Shared channel use',	 
			
	-- PCC:
	rbs_c.Rbs_round_PCC as 'RBs PCC',	rbs_c.maxRBs_PCC as 'Max RBs PCC',	rbs_c.minRBs_PCC as 'Min RBs PCC',	rbs_c.Rbs_dedicated_round_PCC as 'RBs When Allocated PCC',	
	
	tm.[percTM0 PCC] as '% TM Invalid PCC',
	tm.[percTM1 PCC] as '% TM 1: Single Antenna Port 0 PCC',	
	tm.[percTM2 PCC] as '% TM 2: TD Rank 1 PCC',	
	tm.[percTM3 PCC] as '% TM 3: OL SM PCC',
	tm.[percTM4 PCC] as '% TM 4: CL SM PCC',
	tm.[percTM5 PCC] as '% TM 5: MU MIMO PCC',	
	tm.[percTM6 PCC] as '% TM 6: CL RANK1 PC PCC',	
	tm.[percTM7 PCC] as '% TM 7: Single Antenna Port 5 PCC',
	tm.[percTMunknown PCC] as '% TM Unknown PCC',   

	case when cqi4G.averageCQI1 IS NULL then cqi4G.averageCQI0 else ((cqi4G.averageCQI1+cqi4G.averageCQI0)/2) end as 'CQI 4G PCC',		
	
	cqi4G.AverageRI as 'Rank Indicator PCC',	
	
	shcch4G.Percent_LTESharedChannelUse_PCC as 'Shared channel use PCC',	
	
	-- SCC1:
	rbs_c.Rbs_round_SCC1 as 'RBs SCC1',
	rbs_c.maxRBs_SCC1 as 'Max RBs SCC1',
	rbs_c.minRBs_SCC1 as 'Min RBs SCC1',
	rbs_c.Rbs_dedicated_round_SCC1 as 'RBs When Allocated SCC1',	
	
	tm.[percTM0 SCC1] as '% TM Invalid SCC1',
	tm.[percTM1 SCC1] as '% TM 1: Single Antenna Port 0 SCC1',	
	tm.[percTM2 SCC1] as '% TM 2: TD Rank 1 SCC1',	
	tm.[percTM3 SCC1] as '% TM 3: OL SM SCC1',
	tm.[percTM4 SCC1] as '% TM 4: CL SM SCC1',
	tm.[percTM5 SCC1] as '% TM 5: MU MIMO SCC1',	
	tm.[percTM6 SCC1] as '% TM 6: CL RANK1 PC SCC1',	
	tm.[percTM7 SCC1] as '% TM 7: Single Antenna Port 5 SCC1',
	tm.[percTMunknown SCC1] as '% TM Unknown SCC1',   

	case when cqi4G.averageCQI1_SCC1 IS NULL then cqi4G.averageCQI0_SCC1 else ((cqi4G.averageCQI1_SCC1+cqi4G.averageCQI0_SCC1)/2) end as 'CQI 4G SCC1',		
	cqi4G.AverageRI_SCC1 as 'Rank Indicator SCC1',		
	
	shcch4G.Percent_LTESharedChannelUse_SCC1 as 'Shared channel use SCC1',	
	
	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as 'RBs SCC2', null as 'Max RBs SCC2', null as 'Min RBs SCC2', null as 'RBs When Allocated SCC2',		null as 'RBs SCC3', null as 'Max RBs SCC3', null as 'Min RBs SCC3', null as 'RBs When Allocated SCC3',	
	null as 'RBs SCC4', null as 'Max RBs SCC4', null as 'Min RBs SCC4', null as 'RBs When Allocated SCC4',		null as 'RBs SCC5', null as 'Max RBs SCC5', null as 'Min RBs SCC5', null as 'RBs When Allocated SCC5',	
	null as 'RBs SCC6', null as 'Max RBs SCC6', null as 'Min RBs SCC6', null as 'RBs When Allocated SCC6',		null as 'RBs SCC7', null as 'Max RBs SCC7', null as 'Min RBs SCC7', null as 'RBs When Allocated SCC7',	
	
	null as '% TM Invalid SCC2',  null as '% TM 1: Single Antenna Port 0 SCC2',	null as '% TM 2: TD Rank 1 SCC2',	null as '% TM 3: OL SM SCC2', null as '% TM 4: CL SM SCC2', null as '% TM 5: MU MIMO SCC2', null as '% TM 6: CL RANK1 PC SCC2',	null as '% TM 7: Single Antenna Port 5 SCC2', null as '% TM Unknown SCC2',   	
	null as '% TM Invalid SCC3',  null as '% TM 1: Single Antenna Port 0 SCC3',	null as '% TM 2: TD Rank 1 SCC3',	null as '% TM 3: OL SM SCC3', null as '% TM 4: CL SM SCC3', null as '% TM 5: MU MIMO SCC3', null as '% TM 6: CL RANK1 PC SCC3',	null as '% TM 7: Single Antenna Port 5 SCC3', null as '% TM Unknown SCC3',   	
	null as '% TM Invalid SCC4',  null as '% TM 1: Single Antenna Port 0 SCC4',	null as '% TM 2: TD Rank 1 SCC4',	null as '% TM 3: OL SM SCC4', null as '% TM 4: CL SM SCC4', null as '% TM 5: MU MIMO SCC4', null as '% TM 6: CL RANK1 PC SCC4',	null as '% TM 7: Single Antenna Port 5 SCC4', null as '% TM Unknown SCC4',   	
	null as '% TM Invalid SCC5',  null as '% TM 1: Single Antenna Port 0 SCC5',	null as '% TM 2: TD Rank 1 SCC5',	null as '% TM 3: OL SM SCC5', null as '% TM 4: CL SM SCC5', null as '% TM 5: MU MIMO SCC5', null as '% TM 6: CL RANK1 PC SCC5',	null as '% TM 7: Single Antenna Port 5 SCC5', null as '% TM Unknown SCC5',   	
	null as '% TM Invalid SCC6',  null as '% TM 1: Single Antenna Port 0 SCC6',	null as '% TM 2: TD Rank 1 SCC6',	null as '% TM 3: OL SM SCC6', null as '% TM 4: CL SM SCC6', null as '% TM 5: MU MIMO SCC6', null as '% TM 6: CL RANK1 PC SCC6',	null as '% TM 7: Single Antenna Port 5 SCC6', null as '% TM Unknown SCC6',   	
	null as '% TM Invalid SCC7',  null as '% TM 1: Single Antenna Port 0 SCC7',	null as '% TM 2: TD Rank 1 SCC7',	null as '% TM 3: OL SM SCC7', null as '% TM 4: CL SM SCC7', null as '% TM 5: MU MIMO SCC7', null as '% TM 6: CL RANK1 PC SCC7',	null as '% TM 7: Single Antenna Port 5 SCC7', null as '% TM Unknown SCC7',   	

	null as 'CQI 4G SCC2', null as 'Rank Indicator SCC2',	null as 'CQI 4G SCC3', null as 'Rank Indicator SCC3',
	null as 'CQI 4G SCC4', null as 'Rank Indicator SCC4',	null as 'CQI 4G SCC5', null as 'Rank Indicator SCC5',
	null as 'CQI 4G SCC6', null as 'Rank Indicator SCC6',	null as 'CQI 4G SCC7', null as 'Rank Indicator SCC7',
		
	-- INFO RADIO:
	tra.RxLev, 	tra.RxQual, 
	tri.BCCH as BCCH_Ini, tri.BSIC as BSIC_Ini, tri.RxLev as RxLev_Ini, tri.RxQual as RxQual_Ini, 
	trf.BCCH as BCCH_Fin, trf.BSIC as BSIC_Fin,	trf.RxLev as RxLev_Fin,	trf.RxQual as RxQual_Fin,
	tra.RxLev_min, tra.RxQual_min,
	tra.RSCP as 'RSCP_avg',	tra.EcIo as 'EcI0_avg',
	tri.PSC as PSC_Ini,	tri.RSCP as RSCP_Ini, tri.EcIo as EcIo_Ini,	tri.UARFCN as UARFCN_Ini,
	trf.PSC as PSC_Fin,	trf.RSCP as RSCP_Fin, trf.EcIo as EcIo_Fin,	trf.UARFCN as UARFCN_Fin,
	tra.RSCP_min, tra.EcIo_min,
	tra.RSRP as 'RSRP_avg', tra.RSRQ as 'RSRQ_avg', tra.SINR as 'SINR_avg',
	tri.PCI as PCI_Ini,	tri.RSRP as RSRP_Ini, tri.RSRQ as RSRQ_Ini,	tri.SINR as SINR_Ini, tri.EARFCN as EARFCN_Ini,
	trf.PCI as PCI_Fin,	trf.RSRP as RSRP_Fin, trf.RSRQ as RSRQ_Fin, trf.SINR as SINR_Fin, trf.EARFCN as EARFCN_Fin,
	tri.CId as CellId_Ini, tri.LAC as 'LAC/TAC_Ini', tri.RNCID as RNC_Ini,
	trf.CId as CellId_Fin, trf.LAC as 'LAC/TAC_Fin', trf.RNCID as RNC_Fin,

	-- INFO PARCELA:
	tri.longitude as 'Longitud Inicial',	tri.latitude as 'Latitud Inicial',	
	trf.longitude as 'Longitud Final',		trf.latitude as 'Latitud Final',

	-- @DGP: uso de CA
	rbs_c.[Blocks_NoCA],	
	rbs_c.[Blocks_CA],	
	rbs_c.[% CA],			
	
	-- @ERC: Valores calculados a la antigua que se mantienen en caso de querer info en los test fallidos (KPIID no se rellena en esos casos)
	thput_Transf.[ThputApp_nu],		thput_Transf.[DataTransferred_nu],		
	thput_Transf.[SessionTime_nu],	thput_Transf.[TransferTime_nu],	
	1000.0*thput_Transf.[IPAccessTime_nu] as [IPAccessTime_sec_nu],		
	
	-- @ERC: Se añade info de tecnologia inicio/fin para añadir en el reporte
	tri.Tech_Ini,	trf.Tech_Fin,		
	
	-- @DGP: Se añade la info de uso de DC por banda
	mod3G.DualCarrier_use_U2100 as '% Dual Carrier U2100',	mod3G.DualCarrier_use_U900 as '% Dual Carrier U900',
	
	-- @DGP: Se añade la interferencia UL media
	ulint.UL_Interference, 

	-- @ERC: KPIID de P3 - de momento asi, mas adelante (cd funcionen los kpiid) la suma del transfer, dns e ip access
	nullif(dl_kpiid.[SessionTime],0) as SessionTime,
	
	-- @DGP: KPIS CEM
	pdp.PDP_Activate_Ratio,
	pag.Paging_Success_Ratio,
	neigh.EARFCN_N1,
	neigh.PCI_N1,
	neigh.RSRP_N1,
	neigh.RSRQ_N1,
	ho4G.num_HO_S1X2,
	ho4G.duration_S1X2_avg,
	ho4G.S1X2HO_SR,
	win.Max_Win as Max_Window_Size,

	--@CAC: CQI por tecnologia
	cqi3G_900.CQI_UMTS900 as 'CQI UMTS900',
	cqi3G_2100.CQI_UMTS2100 as 'CQI UMTS2100',
	case when cqi4G_2600.averageCQI1_LTE2600 IS NULL then cqi4G_2600.averageCQI0_LTE2600 else ((cqi4G_2600.averageCQI1_LTE2600+cqi4G_2600.averageCQI0_LTE2600)/2) end as 'CQI LTE2600',
	case when cqi4G_1800.averageCQI1_LTE1800 IS NULL then cqi4G_1800.averageCQI0_LTE1800 else ((cqi4G_1800.averageCQI1_LTE1800+cqi4G_1800.averageCQI0_LTE1800)/2) end as 'CQI LTE1800',
	case when cqi4G_800.averageCQI1_LTE800 IS NULL then cqi4G_800.averageCQI0_LTE800 else ((cqi4G_800.averageCQI1_LTE800+cqi4G_800.averageCQI0_LTE800)/2) end as 'CQI LTE800',
	case when cqi4G_2100.averageCQI1_LTE2100 IS NULL then cqi4G_2100.averageCQI0_LTE2100 else ((cqi4G_2100.averageCQI1_LTE2100+cqi4G_2100.averageCQI0_LTE2100)/2) end as 'CQI LTE2100',
	f.IMSI

--into Lcc_Data_HTTPTransfer_DL
from 
	FileList f,	Sessions s, TestInfo t
	-- COMUNES:
		LEFT OUTER JOIN _PCT_TECH_Data	pctTech		on pctTech.TestId=t.TestId and pctTech.SessionId=t.SessionId 
		LEFT OUTER JOIN _lcc_http_DL	dl_kpiid	on dl_kpiid.testid=t.testid and dl_kpiid.sessionid=t.SessionId
		LEFT OUTER JOIN _THPUT thput				on (t.SessionId=thput.SessionId and t.TestId=thput.testid and thput.direction='Downlink')	
		LEFT OUTER JOIN _THPUT_Transf thput_Transf	on (t.SessionId=thput_Transf.SessionId and t.TestId=thput_Transf.testid)		
		LEFT OUTER JOIN _THPUT_RLC		thput_rlc		on (t.SessionId=thput_rlc.SessionId and t.TestId=thput_rlc.testid)	
			
		LEFT OUTER JOIN _TECH_RADIO_INI_Data	tri	on (t.SessionId=tri.SessionId and t.TestId=tri.testid)
		LEFT OUTER JOIN _TECH_RADIO_FIN_Data	trf	on (t.SessionId=trf.SessionId and t.TestId=trf.testid)
		LEFT OUTER JOIN _TECH_RADIO_AVG_Data	tra	on (t.SessionId=tra.SessionId and t.TestId=tra.testid)

	-- 3G:	
		LEFT OUTER JOIN _CQI_3G cqi3G		on cqi3G.TestId=t.TestId and cqi3G.SessionId=t.SessionId
		LEFT OUTER JOIN _CQI_3G_Band cqi3G_2100		on cqi3G_2100.TestId=t.TestId and cqi3G_2100.SessionId=t.SessionId and cqi3G_2100.Band ='UMTS2100'
		LEFT OUTER JOIN _CQI_3G_Band cqi3G_900		on cqi3G_900.TestId=t.TestId and cqi3G_900.SessionId=t.SessionId and cqi3G_900.Band ='UMTS900'

		LEFT OUTER JOIN _scch_use_3G hs3G	on hs3G.TestId=t.TestId and hs3G.SessionId=t.SessionId
		LEFT OUTER JOIN _MOD_3G mod3G		on mod3G.TestId=t.TestId and mod3G.SessionId=t.SessionId
		LEFT OUTER JOIN _HARQ hq			on hq.TestId=t.TestId and hq.SessionId=t.SessionId
		LEFT OUTER JOIN _UL_Int ulint		on ulint.TestId=t.TestId and ulint.SessionId=t.SessionId
	-- 4G:		
		LEFT OUTER JOIN _MOD_4G mod4G			on (t.SessionId=mod4G.SessionId and t.TestId=mod4G.testid and mod4G.direction='Downlink') 
		LEFT OUTER JOIN _SCCH_USE_4G shcch4G	on (t.SessionId=shcch4G.SessionId and t.TestId=shcch4G.testid and shcch4G.direction='Downlink') 
		LEFT OUTER JOIN _cqi_4G cqi4G			on (t.SessionId=cqi4G.SessionId and t.TestId=cqi4G.testid)
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_2600			on (t.SessionId=cqi4G_2600.SessionId and t.TestId=cqi4G_2600.testid and cqi4G_2600.Band ='LTE2600')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_1800			on (t.SessionId=cqi4G_1800.SessionId and t.TestId=cqi4G_1800.testid and cqi4G_1800.Band ='LTE1800')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_800			on (t.SessionId=cqi4G_800.SessionId and t.TestId=cqi4G_800.testid and cqi4G_800.Band ='LTE800')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_2100			on (t.SessionId=cqi4G_2100.SessionId and t.TestId=cqi4G_2100.testid and cqi4G_2100.Band ='LTE2100')
		LEFT OUTER JOIN _RBs_carrier_DL rbs_c	on (t.SessionId=rbs_c.SessionId and t.TestId=rbs_c.testid and rbs_c.direction='Downlink') 
		LEFT OUTER JOIN _RBs_DL rbs				on (t.SessionId=rbs.SessionId and t.TestId=rbs.testid and rbs.direction='Downlink') 
		LEFT OUTER JOIN _TM_DL tm				on (t.SessionId=tm.SessionId and t.TestId=tm.testid and tm.direction='Downlink')

	-- KPI EXTRA:
		LEFT OUTER JOIN _PDP pdp			on pdp.TestId=t.TestId and pdp.SessionId=t.SessionId
		LEFT OUTER JOIN _Paging pag			on pag.TestId=t.TestId and pag.SessionId=t.SessionId
		LEFT OUTER JOIN _NEIGH neigh		on neigh.TestId=t.TestId and neigh.SessionId=t.SessionId
		LEFT OUTER JOIN _4GHO ho4G			on ho4G.TestId=t.TestId and ho4G.SessionId=t.SessionId		
		LEFT OUTER JOIN _Window win			on win.TestId=t.TestId and win.SessionId=t.SessionId	

where 
	t.SessionId=s.SessionId and s.FileId=f.FileId
	and s.sessionType='data' 
	and t.typeoftest='HTTPTransfer' and t.direction='Downlink'
	and s.valid=1 and t.valid=1
	
	and t.testid > @maxTestid_DL
	and RIGHT(LEFT(f.IMSI,5),2) in (1,7,3,4)
order by f.FileId, t.SessionId, t.TestId

select 'Fin creacion tabla Lcc_Data_HTTPTransfer_DL' info


-- (2)
-- ***************************************
------		TABLA FINAL HTTP UL		------			select * from _lcc_http_UL --Lcc_Data_HTTPTransfer_UL 	
-- ***************************************
select 'Inicio creacion tabla Lcc_Data_HTTPTransfer_UL' info

insert into Lcc_Data_HTTPTransfer_UL
select 
	f.CallingModule as MTU,	f.IMEI,		f.CollectionName,	LEFT(f.IMSI,3) as MCC,	RIGHT(LEFT(f.IMSI,5),2) as MNC,	t.startDate,			
	t.startTime,	DATEADD(ms, t.duration ,t.startTime) as endTime,	t.SessionId, f.FileId, t.TestId, t.typeoftest, t.direction, s.info,
	
	-- _lcc_http_UL:
	ul_kpiid.TestType as TestType,	'1' as ServiceType,
	ul_kpiid.[IP Access Time (ms)] ,		ul_kpiid.DataTransferred as DataTransferred,	ul_kpiid.TransferTime as TransferTime, 
	ul_kpiid.ErrorCause as ErrorCause,	ul_kpiid.ErrorType as ErrorType,	
	ul_kpiid.Throughput as Throughput,	'' as Throughput_MAX,

	-- 3G:	
	thput_rlc.maxRLCULThrpt as RLC_MAX,		
	
	-- Technology:		- tech info UL
	ISNULL(pctTech.pctLTE, 0) as '% LTE',	ISNULL(pctTech.pctWCDMA, 0) as '% WCDMA',	ISNULL(pctTech.pctGSM, 0) as '% GSM',	

	ISNULL(pctTech.pct_F1_U2100, 0) as '% F1 U2100',	ISNULL(pctTech.pct_F2_U2100, 0) as '% F2 U2100',	ISNULL(pctTech.pct_F3_U2100, 0) as '% F3 U2100',
	ISNULL(pctTech.pct_F1_U900, 0) as '% F1 U900',	ISNULL(pctTech.pct_F2_U900, 0) as '% F2 U900',
	ISNULL(pctTech.pct_F1_L2600, 0) as '% F1 L2600',	ISNULL(pctTech.pct_F1_L2100, 0) as '% F1 L2100',	ISNULL(pctTech.pct_F2_L2100, 0) as '% F2 L2100',
	ISNULL(pctTech.pct_F1_L1800, 0) as '% F1 L1800',	ISNULL(pctTech.pct_F2_L1800, 0) as '% F2 L1800',	ISNULL(pctTech.pct_F3_L1800, 0) as '% F3 L1800',
	ISNULL(pctTech.pct_F1_L800, 0) as '% F1 L800',
	
	ISNULL(pctTech.pctUMTS_2100, 0) as '% U2100',	ISNULL(pctTech.pctUMTS_900, 0) as '% U900',	ISNULL(pctTech.pctLTE_2600, 0) as '% LTE2600',
	ISNULL(pctTech.pctLTE_2100, 0) as '% LTE2100',	ISNULL(pctTech.pctLTE_1800, 0) as '% LTE1800',
	ISNULL(pctTech.pctLTE_800, 0) as '% LTE800',	
	
	ISNULL(pctTech.[pctGMS_DCS], 0) as 'DCS %',	ISNULL(pctTech.[pctGSM_EGSM], 0) as 'GSM %',	ISNULL(pctTech.[pctGSM_GSM], 0) as 'EGSM %',

	-- 3G:
	sf.PercentSF22 as '% SF22',	sf.PercentSF22andSF42 as '% SF22andSF42',	sf.PercentSF4 as '% SF4',	sf.PercentSF42 as '% SF42',
	
	'' as 'HSUPA 2.0',	case when umac.sumTTI_ms <> 0 then ((1.0*umac.sumTTI_2ms)/(1.0*umac.sumTTI_ms)) else null end as '% TTI 2ms',
	
	--case when cqi3G.DualCarrier_use > 0 then 2 else 1 end as Carriers,	cqi3G.DualCarrier_use as [% Dual Carrier],	
	1 as Carriers,	null as [% Dual Carrier],	
	
	-- 4G:	
	mod4G.[% BPSK] as '% BPSK 4G',	mod4G.[% QPSK] as '% QPSK 4G',	mod4G.[% 16QAM] as '% 16QAM 4G',

	pctTech.pctLTE_10Mhz as '10Mhz Bandwidth %',	pctTech.pctLTE_15Mhz as '15Mhz Bandwidth %',	pctTech.pctLTE_20Mhz as '20Mhz Bandwidth %',
	
	-- Performance
	-- 3G:
	0.01*umac.AverageHappyRate as 'HappyRate', 	0.01*umac.maxHappyRate as 'Happy Rate MAX',umac.AverageSG as 'Serving Grant', 	
	umac.AverageDTXRate as 'DTX',	umac.AverageTBsize as 'avg TBs size',
	sho.percSHO as '% SHO',	'' as 'ReTrx PDU',
	
	-- 4G:
	rbs.Rbs_round as 'RBs',	rbs.maxRBs as 'Max RBs',	rbs.minRBs as 'Min RBs',	rbs.Rbs_dedicated_round as 'RBs When Allocated',
	case when cqi4G.averageCQI1 IS NULL then cqi4G.averageCQI0 else ((cqi4G.averageCQI1+cqi4G.averageCQI0)/2) end as 'CQI 4G',
	
	cqi4G.AverageRI as 'Rank Indicator',	shcch4G.Percent_LTESharedChannelUse as 'Shared channel use',
	
	tm.percTM0 as '% TM Invalid',
	tm.percTM1 as '% TM 1: Single Antenna Port 0',
	tm.percTM2 as '% TM 2: TD Rank 1',	
	tm.percTM3 as '% TM 3: OL SM',	
	tm.percTM4 as '% TM 4: CL SM',
	tm.percTM5 as '% TM 5: MU MIMO',
	tm.percTM6 as '% TM 6: CL RANK1 PC',
	tm.percTM7 as '% TM 7: Single Antenna Port 5',
	tm.percTM8 as '% TM 8',
	tm.percTM9 as '% TM 9',
	tm.percTMunknown as '% TM Unknown',        	

	-- INFO RADIO:
	tra.RxLev,	tra.RxQual,
	tri.BCCH as BCCH_Ini,	tri.BSIC as BSIC_Ini,	tri.RxLev as RxLev_Ini,	tri.RxQual as RxQual_Ini,
	trf.BCCH as BCCH_Fin,	trf.BSIC as BSIC_Fin,	trf.RxLev as RxLev_Fin,	trf.RxQual as RxQual_Fin,
	tra.RxLev_min,	tra.RxQual_min,
	tra.RSCP as 'RSCP_avg',	tra.EcIo as 'EcI0_avg',
	tri.PSC as PSC_Ini,	tri.RSCP as RSCP_Ini,	tri.EcIo as EcIo_Ini,	tri.UARFCN as UARFCN_Ini,
	trf.PSC as PSC_Fin,	trf.RSCP as RSCP_Fin,	trf.EcIo as EcIo_Fin,	trf.UARFCN as UARFCN_Fin,
	tra.RSCP_min,	tra.EcIo_min,
	tra.RSRP as 'RSRP_avg',	tra.RSRQ as 'RSRQ_avg',	tra.SINR as 'SINR_avg',
	tri.PCI as PCI_Ini,	tri.RSRP as RSRP_Ini,	tri.RSRQ as RSRQ_Ini,	tri.SINR as SINR_Ini,		tri.EARFCN as EARFCN_Ini,
	trf.PCI as PCI_Fin,	trf.RSRP as RSRP_Fin,	trf.RSRQ as RSRQ_Fin,	trf.SINR as SINR_Fin,		trf.EARFCN as EARFCN_Fin,
	tri.CId as CellId_Ini,	tri.LAC as 'LAC/TAC_Ini',	tri.RNCID as RNC_Ini,
	trf.CId as CellId_Fin,	trf.LAC as 'LAC/TAC_Fin',	trf.RNCID as RNC_Fin,

	---------------
	-- INFO PARCELA:
	tri.longitude as 'Longitud Inicial',	tri.latitude as 'Latitud Inicial',	
	trf.longitude as 'Longitud Final',	trf.latitude as 'Latitud Final',

	-- @ERC: Valores sin updates para montar los libros externos de errores de datos
	thput_Transf.[ThputApp_nu],			thput_Transf.[DataTransferred_nu],		thput_Transf.[SessionTime_nu],		
	thput_Transf.[TransferTime_nu],		1000.0*thput_Transf.[IPAccessTime_nu] as [IPAccessTime_sec_nu], -- este no se borra ya que no se calculan kpi en DL/UL, pero si se hiciera mas adelante -> bastaria un update al otro campo		
	
	-- @ERC: Se añade info de tecnologia inicio/fin para añadir en el reporte
	tri.Tech_Ini,	trf.Tech_Fin,		
	
	-- @DGP: Se añade la info de uso de DC por banda
	--cqi3G.DualCarrier_use_U2100 as '% Dual Carrier U2100',	cqi3G.DualCarrier_use_U900 as '% Dual Carrier U900',
	null as '% Dual Carrier U2100',	null as '% Dual Carrier U900',
	-- @DGP: Se añade la interferencia UL media
	ulint.UL_Interference,

	-- @ERC: KPIID de P3 - de momento asi, mas adelante (cd funcionen los kpiid) la suma del transfer, dns e ip access
	nullif(ul_kpiid.sessionTime,0) as SessionTime,
	
	--@DGP: KPIS CEM
	pdp.PDP_Activate_Ratio,
	pag.Paging_Success_Ratio,
	neigh.EARFCN_N1,
	neigh.PCI_N1,
	neigh.RSRP_N1,
	neigh.RSRQ_N1,
	ho4G.num_HO_S1X2,
	ho4G.duration_S1X2_avg,
	ho4G.S1X2HO_SR,
	win.Max_Win as Max_Window_Size,

	--@CAC: CQI por tecnologia
	case when cqi4G_2600.averageCQI1_LTE2600 IS NULL then cqi4G_2600.averageCQI0_LTE2600 else ((cqi4G_2600.averageCQI1_LTE2600+cqi4G_2600.averageCQI0_LTE2600)/2) end as 'CQI LTE2600',
	case when cqi4G_1800.averageCQI1_LTE1800 IS NULL then cqi4G_1800.averageCQI0_LTE1800 else ((cqi4G_1800.averageCQI1_LTE1800+cqi4G_1800.averageCQI0_LTE1800)/2) end as 'CQI LTE1800',
	case when cqi4G_800.averageCQI1_LTE800 IS NULL then cqi4G_800.averageCQI0_LTE800 else ((cqi4G_800.averageCQI1_LTE800+cqi4G_800.averageCQI0_LTE800)/2) end as 'CQI LTE800',
	case when cqi4G_2100.averageCQI1_LTE2100 IS NULL then cqi4G_2100.averageCQI0_LTE2100 else ((cqi4G_2100.averageCQI1_LTE2100+cqi4G_2100.averageCQI0_LTE2100)/2) end as 'CQI LTE2100',
	f.IMSI
	
--into Lcc_Data_HTTPTransfer_UL
from 
	FileList f, Sessions s, TestInfo t
	-- COMUNES:
		LEFT OUTER JOIN _PCT_TECH_Data pctTech		on (pctTech.TestId=t.TestId and pctTech.SessionId=t.SessionId )
		LEFT OUTER JOIN _lcc_http_UL ul_kpiid		on (ul_kpiid.TestId=t.TestId and ul_kpiid.SessionId=t.SessionId )
		LEFT OUTER JOIN _THPUT thput				on (t.SessionId=thput.SessionId and t.TestId=thput.testid and thput.direction='Uplink')	
		LEFT OUTER JOIN _THPUT_Transf thput_Transf	on (t.SessionId=thput_Transf.SessionId and t.TestId=thput_Transf.testid)		
		LEFT OUTER JOIN _THPUT_RLC thput_rlc		on (t.SessionId=thput_rlc.SessionId and t.TestId=thput_rlc.testid)
		
		LEFT OUTER JOIN _TECH_RADIO_INI_Data tri	on (t.SessionId=tri.SessionId and t.TestId=tri.testid)
		LEFT OUTER JOIN _TECH_RADIO_FIN_Data trf	on (t.SessionId=trf.SessionId and t.TestId=trf.testid)
		LEFT OUTER JOIN _TECH_RADIO_AVG_Data tra	on (t.SessionId=tra.SessionId and t.TestId=tra.testid)	
	
	-- 3G:
		LEFT OUTER JOIN _SF sf				on sf.TestId=t.TestId and sf.SessionId=t.SessionId
		LEFT OUTER JOIN _ULMAC umac			on umac.TestId=t.TestId and umac.SessionId=t.SessionId
		LEFT OUTER JOIN _CQI_3G cqi3G		on cqi3G.TestId=t.TestId and cqi3G.SessionId=t.SessionId
		LEFT OUTER JOIN _SHOs sho			on sho.TestId=t.TestId and sho.SessionId=t.SessionId
		LEFT OUTER JOIN _UL_Int ulint		on ulint.TestId=t.TestId and ulint.SessionId=t.SessionId		
	-- 4G:
		LEFT OUTER JOIN _MOD_4G mod4G			on (t.SessionId=mod4G.SessionId and t.TestId=mod4G.testid and mod4G.Direction='Uplink') 
		LEFT OUTER JOIN _SCCH_USE_4G shcch4G	on (t.SessionId=shcch4G.SessionId and t.TestId=shcch4G.testid and shcch4G.Direction='Uplink') 
		LEFT OUTER JOIN _CQI_4G cqi4G			on (t.SessionId=cqi4G.SessionId and t.TestId=cqi4G.testid)
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_2600			on (t.SessionId=cqi4G_2600.SessionId and t.TestId=cqi4G_2600.testid and cqi4G_2600.Band ='LTE2600')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_1800			on (t.SessionId=cqi4G_1800.SessionId and t.TestId=cqi4G_1800.testid and cqi4G_1800.Band ='LTE1800')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_800			on (t.SessionId=cqi4G_800.SessionId and t.TestId=cqi4G_800.testid and cqi4G_800.Band ='LTE800')
		LEFT OUTER JOIN _CQI_4G_Band cqi4G_2100			on (t.SessionId=cqi4G_2100.SessionId and t.TestId=cqi4G_2100.testid and cqi4G_2100.Band ='LTE2100')		
		LEFT OUTER JOIN _RBs_UL rbs				on (t.SessionId=rbs.SessionId and t.TestId=rbs.testid and rbs.Direction='Uplink') 
		LEFT OUTER JOIN _TM_UL tm				on (t.SessionId=tm.SessionId and t.TestId=tm.testid)

	-- KPI EXTRA:
		LEFT OUTER JOIN _PDP pdp			on pdp.TestId=t.TestId and pdp.SessionId=t.SessionId
		LEFT OUTER JOIN _Paging pag			on pag.TestId=t.TestId and pag.SessionId=t.SessionId
		LEFT OUTER JOIN _NEIGH neigh		on neigh.TestId=t.TestId and neigh.SessionId=t.SessionId
		LEFT OUTER JOIN _4GHO ho4G			on ho4G.TestId=t.TestId and ho4G.SessionId=t.SessionId		
		LEFT OUTER JOIN _Window win			on win.TestId=t.TestId and win.SessionId=t.SessionId
where 
	t.SessionId=s.SessionId and s.FileId=f.FileId
	and s.sessionType='data'  
	and t.typeoftest='HTTPTransfer' and t.direction='Uplink'
	and s.valid=1 and t.valid=1
	
	and t.testid > @maxTestid_UL
	and RIGHT(LEFT(f.IMSI,5),2) in (1,7,3,4)	
order by f.FileId, t.SessionId, t.TestId	

select 'Fin creacion tabla Lcc_Data_HTTPTransfer_UL' info


-- (3)
-- *********************************************
----		TABLA FINAL HTTP Browser		----	select * from Lcc_Data_HTTPTransfer_DL -- _lcc_http_DL
-- *********************************************
select 'Inicio creacion tabla Lcc_Data_HTTPBrowser' info

insert into Lcc_Data_HTTPBrowser
select
	-- Info general 
	f.CallingModule as MTU,	f.IMEI,		f.CollectionName,	LEFT(f.IMSI,3) as MCC,	RIGHT(LEFT(f.IMSI,5),2) as MNC,	t.startDate,
	t.startTime,	DATEADD(ms, t.duration ,t.startTime) as endTime,	t.SessionId, f.FileId, t.TestId, t.typeoftest, t.direction, s.info,

	-- _lcc_http_browser
	br_kpiid.Testtype as TestType, '2' as 'ServiceType',	
	br_kpiid.DataTransferred as 'DataTransferred',		
	br_kpiid.ErrorCause as 'ErrorCause',
	br_kpiid.ErrorType,
	br_kpiid.Throughput as 'Throughput',	

	thput.maxThput_kbps as Throughput_MAX,
	
	-- PCC:
	thput.DataTransferred_PCC as DataTransferred_PCC,	thput.TransferTime_PCC as TransferTime_PCC,	
	thput.avgThput_kbps_PCC as Throughput_PCC,			thput.maxThput_kbps_PCC as Throughput_MAX_PCC,
		
	-- SCC1:	- De momento solo se calcula para la SCC1
	thput.DataTransferred_SCC1 as DataTransferred_SCC1,		thput.TransferTime_SCC1 as TransferTime_SCC1,
	thput.avgThput_kbps_SCC1 as Throughput_SCC1,			thput.maxThput_kbps_SCC1 as Throughput_MAX_SCC1,
	
	-- Web Time Kepler y Web Time Mobile Kepler:
	-- Times:
	br_kpiid.IPAccessT/1000.0 as 'IP Service Setup Time (s)',
	isnull(br_kpiid.DNST/1000.0,0 )as 'DNS Resolution (s)',	
	br_kpiid.transferT/1000.0 as 'Transfer Time (s)',
	br_kpiid.sessionT/1000.0  as 'Session Time (s)',		-- es la suma del DNs time y el session time

	-- Technology:		- tech info DL
	-- PCC:
	ISNULL(pctTech.pctLTE, 0) as '% LTE',	ISNULL(pctTech.pctWCDMA, 0) as '% WCDMA',	ISNULL(pctTech.pctGSM, 0) as '% GSM',
	ISNULL(pctTech.pct_F1_U2100, 0) as '% F1 U2100',	ISNULL(pctTech.pct_F2_U2100, 0) as '% F2 U2100',	ISNULL(pctTech.pct_F3_U2100, 0) as '% F3 U2100',
	ISNULL(pctTech.pct_F1_U900, 0) as '% F1 U900',		ISNULL(pctTech.pct_F2_U900, 0) as '% F2 U900',		ISNULL(pctTech.pct_F1_L2600, 0) as '% F1 L2600',
	ISNULL(pctTech.pct_F1_L2100, 0) as '% F1 L2100',	ISNULL(pctTech.pct_F2_L2100, 0) as '% F2 L2100',	ISNULL(pctTech.pct_F1_L1800, 0) as '% F1 L1800',
	ISNULL(pctTech.pct_F2_L1800, 0) as '% F2 L1800',	ISNULL(pctTech.pct_F3_L1800, 0) as '% F3 L1800',	ISNULL(pctTech.pct_F1_L800, 0) as '% F1 L800',	
	ISNULL(pctTech.pctUMTS_2100, 0) as '% U2100',	ISNULL(pctTech.pctUMTS_900, 0) as '% U900',		ISNULL(pctTech.pctLTE_2600, 0) as '% LTE2600',
	ISNULL(pctTech.pctLTE_2100, 0) as '% LTE2100',	ISNULL(pctTech.pctLTE_1800, 0) as '% LTE1800',	ISNULL(pctTech.pctLTE_800, 0) as '% LTE800',			
	ISNULL(pctTech.[pctGMS_DCS], 0) as 'DCS %',		ISNULL(pctTech.[pctGSM_EGSM], 0) as 'GSM %',	ISNULL(pctTech.[pctGSM_GSM], 0) as 'EGSM %',
	
	-- SCC1:	- De momento solo se calcula para la SCC1
	ISNULL(pctTech.pctLTE_2600_SCC1, 0) as '% LTE2600_SCC1',	ISNULL(pctTech.pctLTE_1800_SCC1, 0) as '% LTE1800_SCC1',	ISNULL(pctTech.pctLTE_800_SCC1, 0) as '% LTE800_SCC1',	

	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '% LTE2600_SCC2', null as '% LTE1800_SCC2', null as '% LTE800_SCC2',	null as '% LTE2600_SCC3', null as '% LTE1800_SCC3', null as '% LTE800_SCC3',	null as '% LTE2600_SCC4', null as '% LTE1800_SCC4', null as '% LTE800_SCC4',
	null as '% LTE2600_SCC5', null as '% LTE1800_SCC5', null as '% LTE800_SCC5',	null as '% LTE2600_SCC6', null as '% LTE1800_SCC6', null as '% LTE800_SCC6',	null as '% LTE2600_SCC7', null as '% LTE1800_SCC7', null as '% LTE800_SCC7',

	-- 3G:
	case when cqi3G.DualCarrier_use > 0 then 2 else 1 end as Carriers,	
	cqi3G.DualCarrier_use as [% Dual Carrier],		
	
	-- INFO RADIO:
	tra.RxLev,	tra.RxQual,
	tri.BCCH as BCCH_Ini,	tri.BSIC as BSIC_Ini,	tri.RxLev as RxLev_Ini,	tri.RxQual as RxQual_Ini,
	trf.BCCH as BCCH_Fin,	trf.BSIC as BSIC_Fin,	trf.RxLev as RxLev_Fin,	trf.RxQual as RxQual_Fin,
	tra.RxLev_min,	tra.RxQual_min,
	tra.RSCP as 'RSCP_avg',	tra.EcIo as 'EcI0_avg',
	tri.PSC as PSC_Ini,	tri.RSCP as RSCP_Ini,	tri.EcIo as EcIo_Ini,	tri.UARFCN as UARFCN_Ini,
	trf.PSC as PSC_Fin,	trf.RSCP as RSCP_Fin,	trf.EcIo as EcIo_Fin,	trf.UARFCN as UARFCN_Fin,
	tra.RSCP_min,	tra.EcIo_min,
	tra.RSRP as 'RSRP_avg',	tra.RSRQ as 'RSRQ_avg',	tra.SINR as 'SINR_avg',
	tri.PCI as PCI_Ini,	tri.RSRP as RSRP_Ini,	tri.RSRQ as RSRQ_Ini,	tri.SINR as SINR_Ini,		tri.EARFCN as EARFCN_Ini,
	trf.PCI as PCI_Fin,	trf.RSRP as RSRP_Fin,	trf.RSRQ as RSRQ_Fin,	trf.SINR as SINR_Fin,		trf.EARFCN as EARFCN_Fin,
	tri.CId as CellId_Ini,	tri.LAC as 'LAC/TAC_Ini',	tri.RNCID as RNC_Ini,
	trf.CId as CellId_Fin,	trf.LAC as 'LAC/TAC_Fin',	trf.RNCID as RNC_Fin,

	-- INFO PARCELA:	
	tri.longitude as 'Longitud Inicial',	tri.latitude as 'Latitud Inicial',	
	trf.longitude as 'Longitud Final',		trf.latitude as 'Latitud Final',

	-- @ERC: Valores sin updates para si hiciera falta montar los libros externos de errores de datos mas adelante
	br_kpiid.DataTransferred_nu as DataTransferred_nu,		br_kpiid.ThputApp_nu as ThputApp_nu,				br_kpiid.IPAccessTime_nu/1000.0 as IP_AccessTime_sec_nu,		
	br_kpiid.TransferTime_nu/1000.0 as Transfer_Time_sec_nu,		br_kpiid.SessionTime_nu/1000.0  as SessionTime_sec_nu,		br_kpiid.DNSTime_nu/1000.0 as DNSTime_nu,  

	-- @ERC: Se añade info de tecnologia inicio/fin para añadir en el reporte
	tri.Tech_Ini,	trf.Tech_Fin,		
	
	-- @DGP: Se añade la info de uso de DC por banda
	cqi3G.DualCarrier_use_U2100 as '% Dual Carrier U2100',	cqi3G.DualCarrier_use_U900 as '% Dual Carrier U900',
	
	-- @DGP: Se añade la interferencia UL media
	ulint.UL_Interference,

	--@DGP: KPIS CEM
	pdp.PDP_Activate_Ratio,
	pag.Paging_Success_Ratio,
	neigh.EARFCN_N1,
	neigh.PCI_N1,
	neigh.RSRP_N1,
	neigh.RSRQ_N1,
	ho4G.num_HO_S1X2,
	ho4G.duration_S1X2_avg,
	ho4G.S1X2HO_SR,
	win.Max_Win as Max_Window_Size,
	f.IMSI
	
--into Lcc_Data_HTTPBrowser	 
from 
	FileList f,	Sessions s, TestInfo t
		LEFT OUTER JOIN _PCT_TECH_Data pctTech			on pctTech.TestId=t.TestId and pctTech.SessionId=t.SessionId 
		LEFT OUTER JOIN _lcc_http_browser br_kpiid		on br_kpiid.TestId=t.TestId and br_kpiid.SessionId=t.SessionId 
		LEFT OUTER JOIN _THPUT thput					on thput.SessionId=t.SessionId and thput.TestId=t.TestId and thput.direction='Downlink'		
		LEFT OUTER JOIN _TECH_RADIO_INI_Data tri		on t.SessionId=tri.SessionId and t.TestId=tri.testid
		LEFT OUTER JOIN _TECH_RADIO_FIN_Data trf		on t.SessionId=trf.SessionId and t.TestId=trf.testid
		LEFT OUTER JOIN _TECH_RADIO_AVG_Data tra		on t.SessionId=tra.SessionId and t.TestId=tra.testid
		LEFT OUTER JOIN _CQI_3G cqi3G			on cqi3G.TestId=t.TestId and cqi3G.SessionId=t.SessionId
		LEFT OUTER JOIN _UL_Int ulint			on ulint.TestId=t.TestId and ulint.SessionId=t.SessionId

		-- KPI EXTRA:
		LEFT OUTER JOIN _PDP pdp			on pdp.TestId=t.TestId and pdp.SessionId=t.SessionId
		LEFT OUTER JOIN _Paging pag			on pag.TestId=t.TestId and pag.SessionId=t.SessionId
		LEFT OUTER JOIN _NEIGH neigh		on neigh.TestId=t.TestId and neigh.SessionId=t.SessionId
		LEFT OUTER JOIN _4GHO ho4G			on ho4G.TestId=t.TestId and ho4G.SessionId=t.SessionId		
		LEFT OUTER JOIN _Window win			on win.TestId=t.TestId and win.SessionId=t.SessionId

where 
	t.SessionId=s.SessionId and s.FileId=f.FileId
	and s.sessionType='data' 
	and t.typeoftest='HTTPBrowser' 
	and s.valid=1 and t.valid=1
	
	and t.testid > @maxTestid_BR
	and RIGHT(LEFT(f.IMSI,5),2) in (1,7,3,4)	

	
order by f.FileId, t.SessionId, t.TestId

select 'Fin creacion tabla Lcc_Data_HTTPBrowser' info


-- (4)
-- *************************************
----		TABLA FINAL Youtube		----			select * from Lcc_Data_HTTPTransfer_DL -- _lcc_http_DL
-- *************************************
select 'Inicio creacion tabla from Lcc_Data_YOUTUBE' info

insert into Lcc_Data_YOUTUBE
select 
	-- Info general 
	f.CallingModule as MTU,	f.IMEI,		f.CollectionName,	LEFT(f.IMSI,3) as MCC,	RIGHT(LEFT(f.IMSI,5),2) as MNC,	t.startDate,
	t.startTime,	DATEADD(ms, t.duration ,t.startTime) as endTime,	t.SessionId, f.FileId, t.TestId, t.typeoftest, t.direction, s.info,
	
	t.testname, ytb.[Image Resolution] as 'Video Resolution',

	--	B1 :	YouTube Service Access Success Ratio [%]  
	case when ytb.status_B1 = 'Successful' then null else 'Failed' end as 'Fails',
	case when ytb.status_B1 = 'Successful' then null else ytb.status_B1 end as 'Cause',
	case when ytb.status_B1 = 'Successful' then null else
		case when ytb.status_B1 = 'Player Access Timeout exceeded' then dateadd(ms,ytb.Duration10620*1000, ytb.StartIPserviceAccess)
			when ytb.status_B1 = 'Player Download Timeout exceeded' then dateadd(ms, (ytb.Duration10620+ytb.Duration20620)*1000, ytb.StartIPserviceAccess)
			when ytb.status_B1 = 'Video Access Timeout exceeded' then dateadd(ms, ytb.Duration10625*1000, ytb.StartIPserviceAccess)
			when ytb.status_B1 = 'Video Reproduction Timeout exceeded' then dateadd(ms, (ytb.Duration10625+ytb.Duration30621)*1000, ytb.StartIPserviceAccess)
			else ytb.[Block Time] --Si no es error por timeout, el tiempo de bloqueo será el de antes
		end 
	end as 'Block Time',	
	
	-- Tiempo hasta el Start of video playback - first frame displayed in player - Video Access Time (KPI 10621+el KPI 30621)
	case when ytb.status_B1 = 'Successful' then ytb.[Time To First Image [s]]] end as '[Time To First Image [s]]]',
	
	ytb.[Video Freeze Occurrences > 300ms] as 'Num. Interruptions',
	ytb.[Video Freezing Impairment > 300ms],
		 
	ytb.[Accumulated Video Freezing Duration [s]] > 300ms] as 'Accumulated Video Freezing Duration [s]',
	ytb.[Video Average Freezing Duration [s]] > 300ms] as 'Average Video Freezing Duration [s]',
	ytb.[Video Maximum Freezing Duration [s]] > 300ms] as 'Maximum Video Freezing Duration [s]',
	
	-- B2:	 B1.1 success + freezing events and Playout (status20621)
	case when ytb.status_B1 <> 'Successful' or ytb.status20621<>'Successful' then 'W Interruptions'
	else (case when ytb.[Video Freezing Impairment > 300ms]='Freezings'  or ytb.status20621<>'Successful'then 'W Interruptions'
			   when ytb.[Video Freezing Impairment > 300ms]='No Freezings' and ytb.status20621='Successful' then 'W/O Interruptions' end) end as 'End Status',  

	-- B3:	distinto a los requisitos de P3:
	case when  ytb.status_B1 <> 'Successful' or ytb.status20621<>'Successful' then 'Failed' --Fallos
		else case when ytb.status_B1 <> 'Video Access Timeout exceeded' --Entrarían ya como fallos en el B1, pero por seguir las condiciones de la metodología
					and ytb.status_B1 <> 'Video Reproduction Timeout exceeded'  --Entrarían ya como fallos en el B1, pero por seguir las condiciones de la metodología
					and isnull([Video Maximum Freezing Duration [s]] > 300ms],0) <=8 --Ningún freezings de más de 8 segundos
					and isnull([Accumulated Video Freezing Duration [s]] > 300ms],0) < 15 --Suma de todos los frezing menor a 15 segundos
					and isnull([Video Freeze Occurrences > 300ms],0) <= 10 --No más de 10 freezings
					and ytb.status20621='Successful'
				then 'Successful'
				else 'Failed' end
	end as 'Succeesful_Video_Download',

	-- Technology:		info tech DL
	-- PCC:
	ISNULL(pctTech.pctLTE, 0) as '% LTE',				ISNULL(pctTech.pctWCDMA, 0) as '% WCDMA',			ISNULL(pctTech.pctGSM, 0) as '% GSM',
	ISNULL(pctTech.pct_F1_U2100, 0) as '% F1 U2100',	ISNULL(pctTech.pct_F2_U2100, 0) as '% F2 U2100',	ISNULL(pctTech.pct_F3_U2100, 0) as '% F3 U2100',
	ISNULL(pctTech.pct_F1_U900, 0) as '% F1 U900',		ISNULL(pctTech.pct_F2_U900, 0) as '% F2 U900',		ISNULL(pctTech.pct_F1_L2600, 0) as '% F1 L2600',
	ISNULL(pctTech.pct_F1_L2100, 0) as '% F1 L2100',	ISNULL(pctTech.pct_F2_L2100, 0) as '% F2 L2100',	ISNULL(pctTech.pct_F1_L1800, 0) as '% F1 L1800',
	ISNULL(pctTech.pct_F2_L1800, 0) as '% F2 L1800',	ISNULL(pctTech.pct_F3_L1800, 0) as '% F3 L1800',	ISNULL(pctTech.pct_F1_L800, 0) as '% F1 L800',	
	ISNULL(pctTech.pctUMTS_2100, 0) as '% U2100',	ISNULL(pctTech.pctUMTS_900, 0) as '% U900',				ISNULL(pctTech.pctLTE_2600, 0) as '% LTE2600',
	ISNULL(pctTech.pctLTE_2100, 0) as '% LTE2100',	ISNULL(pctTech.pctLTE_1800, 0) as '% LTE1800',			ISNULL(pctTech.pctLTE_800, 0) as '% LTE800',			
	ISNULL(pctTech.[pctGMS_DCS], 0) as 'DCS %',		ISNULL(pctTech.[pctGSM_EGSM], 0) as 'GSM %',			ISNULL(pctTech.[pctGSM_GSM], 0) as 'EGSM %',
	
	-- SCC1:	- De momento solo se calcula para la SCC1
	ISNULL(pctTech.pctLTE_2600_SCC1, 0) as '% LTE2600_SCC1',	ISNULL(pctTech.pctLTE_1800_SCC1, 0) as '% LTE1800_SCC1',	ISNULL(pctTech.pctLTE_800_SCC1, 0) as '% LTE800_SCC1',	

	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '% LTE2600_SCC2', null as '% LTE1800_SCC2', null as '% LTE800_SCC2',	null as '% LTE2600_SCC3', null as '% LTE1800_SCC3', null as '% LTE800_SCC3',	null as '% LTE2600_SCC4', null as '% LTE1800_SCC4', null as '% LTE800_SCC4',
	null as '% LTE2600_SCC5', null as '% LTE1800_SCC5', null as '% LTE800_SCC5',	null as '% LTE2600_SCC6', null as '% LTE1800_SCC6', null as '% LTE800_SCC6',	null as '% LTE2600_SCC7', null as '% LTE1800_SCC7', null as '% LTE800_SCC7',
	
	-- INFO RADIO:
	tra.RxLev,	tra.RxQual,
	tri.BCCH as BCCH_Ini,	tri.BSIC as BSIC_Ini,	tri.RxLev as RxLev_Ini,	tri.RxQual as RxQual_Ini,
	trf.BCCH as BCCH_Fin,	trf.BSIC as BSIC_Fin,	trf.RxLev as RxLev_Fin,	trf.RxQual as RxQual_Fin,
	tra.RxLev_min,	tra.RxQual_min,
	tra.RSCP as 'RSCP_avg',	tra.EcIo as 'EcI0_avg',
	tri.PSC as PSC_Ini,	tri.RSCP as RSCP_Ini,	tri.EcIo as EcIo_Ini,	tri.UARFCN as UARFCN_Ini,
	trf.PSC as PSC_Fin,	trf.RSCP as RSCP_Fin,	trf.EcIo as EcIo_Fin,	trf.UARFCN as UARFCN_Fin,
	tra.RSCP_min,	tra.EcIo_min,
	tra.RSRP as 'RSRP_avg',	tra.RSRQ as 'RSRQ_avg',	tra.SINR as 'SINR_avg',
	tri.PCI as PCI_Ini,	tri.RSRP as RSRP_Ini,	tri.RSRQ as RSRQ_Ini,	tri.SINR as SINR_Ini,		tri.EARFCN as EARFCN_Ini,
	trf.PCI as PCI_Fin,	trf.RSRP as RSRP_Fin,	trf.RSRQ as RSRQ_Fin,	trf.SINR as SINR_Fin,		trf.EARFCN as EARFCN_Fin,
	tri.CId as CellId_Ini,	tri.LAC as 'LAC/TAC_Ini',	tri.RNCID as RNC_Ini,
	trf.CId as CellId_Fin,	trf.LAC as 'LAC/TAC_Fin',	trf.RNCID as RNC_Fin,

	-- INFO PARCELA:
	tri.longitude as 'Longitud Inicial',	tri.latitude as 'Latitud Inicial',	
	trf.longitude as 'Longitud Final',		trf.latitude as 'Latitud Final'	,

	-- @ERC: Se añade info de tecnologia inicio/fin para añadir en el reporte
	tri.Tech_Ini,	trf.Tech_Fin,

	--@DGP: KPIS CEM
	pdp.PDP_Activate_Ratio,
	pag.Paging_Success_Ratio,
	neigh.EARFCN_N1,
	neigh.PCI_N1,
	neigh.RSRP_N1,
	neigh.RSRQ_N1,
	ho4G.num_HO_S1X2,
	ho4G.duration_S1X2_avg,
	ho4G.S1X2HO_SR,
	win.Max_Win as Max_Window_Size,
	buf.Buffering_Time as Buffering_Time_Sec,
	null as Video_MOS,
	f.IMSI
	
--into Lcc_Data_YOUTUBE		
from 
	FileList f,	Sessions s, TestInfo t
		LEFT OUTER JOIN _PCT_TECH_Data pctTech			on pctTech.TestId=t.TestId and pctTech.SessionId=t.SessionId 
		LEFT OUTER JOIN _TECH_RADIO_INI_Data tri		on (t.SessionId=tri.SessionId and t.TestId=tri.testid)
		LEFT OUTER JOIN _TECH_RADIO_FIN_Data trf		on (t.SessionId=trf.SessionId and t.TestId=trf.testid)
		LEFT OUTER JOIN _TECH_RADIO_AVG_Data tra		on (t.SessionId=tra.SessionId and t.TestId=tra.testid)	
		LEFT OUTER JOIN _ETSIYouTubeKPIs ytb			on (t.SessionId=ytb.SessionId and t.TestId=ytb.testid)

		-- KPI EXTRA:
		LEFT OUTER JOIN _PDP pdp		on pdp.TestId=t.TestId and pdp.SessionId=t.SessionId
		LEFT OUTER JOIN _Paging pag		on pag.TestId=t.TestId and pag.SessionId=t.SessionId
		LEFT OUTER JOIN _NEIGH neigh		on neigh.TestId=t.TestId and neigh.SessionId=t.SessionId
		LEFT OUTER JOIN _4GHO ho4G			on ho4G.TestId=t.TestId and ho4G.SessionId=t.SessionId		
		LEFT OUTER JOIN _Window win			on win.TestId=t.TestId and win.SessionId=t.SessionId	
		LEFT OUTER JOIN _Buffer buf			on buf.TestId=t.TestId and buf.SessionId=t.SessionId
					
where 
	t.SessionId=s.SessionId and s.FileId=f.FileId
	and s.sessionType='data' 
	and t.typeoftest like '%YouTube%' 
	and t.valid=1 and s.valid=1 
	
	and t.testid > @maxTestid_YTB
	and RIGHT(LEFT(f.IMSI,5),2) in (1,7,3,4)	
	
	
order by f.FileId, t.SessionId, t.TestId

select 'Fin creacion tabla Lcc_Data_YOUTUBE' info


---- (5)
---- *************************************
------		TABLA FINAL Latencias	  ----			select * from Lcc_Data_Latencias -- _lcc_http_DL
---- *************************************
select 'Inicio creacion tabla Lcc_Data_Latencias' info

insert into Lcc_Data_Latencias
select
	-- Info general 
	f.CallingModule as MTU,	f.IMEI,		f.CollectionName,	LEFT(f.IMSI,3) as MCC,	RIGHT(LEFT(f.IMSI,5),2) as MNC,	t.startDate,
	t.startTime,	DATEADD(ms, t.duration ,t.startTime) as endTime,	t.SessionId, f.FileId, t.TestId, t.typeoftest, t.direction, s.info,
	
	-- _lcc_http_latencias:
	_lat_kpiid.Duration ,
	
--------------
-- Technology:		- tech info DL
	-- PCC:
	ISNULL(pctTech.pctLTE, 0) as '% LTE',				ISNULL(pctTech.pctWCDMA, 0) as '% WCDMA',			ISNULL(pctTech.pctGSM, 0) as '% GSM',
	ISNULL(pctTech.pct_F1_U2100, 0) as '% F1 U2100',	ISNULL(pctTech.pct_F2_U2100, 0) as '% F2 U2100',	ISNULL(pctTech.pct_F3_U2100, 0) as '% F3 U2100',
	ISNULL(pctTech.pct_F1_U900, 0) as '% F1 U900',		ISNULL(pctTech.pct_F2_U900, 0) as '% F2 U900',		ISNULL(pctTech.pct_F1_L2600, 0) as '% F1 L2600',
	ISNULL(pctTech.pct_F1_L2100, 0) as '% F1 L2100',	ISNULL(pctTech.pct_F2_L2100, 0) as '% F2 L2100',	ISNULL(pctTech.pct_F1_L1800, 0) as '% F1 L1800',
	ISNULL(pctTech.pct_F2_L1800, 0) as '% F2 L1800',	ISNULL(pctTech.pct_F3_L1800, 0) as '% F3 L1800',	ISNULL(pctTech.pct_F1_L800, 0) as '% F1 L800',	
	ISNULL(pctTech.pctUMTS_2100, 0) as '% U2100',	ISNULL(pctTech.pctUMTS_900, 0) as '% U900',				ISNULL(pctTech.pctLTE_2600, 0) as '% LTE2600',
	ISNULL(pctTech.pctLTE_2100, 0) as '% LTE2100',	ISNULL(pctTech.pctLTE_1800, 0) as '% LTE1800',			ISNULL(pctTech.pctLTE_800, 0) as '% LTE800',			
	ISNULL(pctTech.[pctGMS_DCS], 0) as 'DCS %',		ISNULL(pctTech.[pctGSM_EGSM], 0) as 'GSM %',			ISNULL(pctTech.[pctGSM_GSM], 0) as 'EGSM %',
	
	-- SCC1:	- De momento solo se calcula para la SCC1
	ISNULL(pctTech.pctLTE_2600_SCC1, 0) as '% LTE2600_SCC1',	ISNULL(pctTech.pctLTE_1800_SCC1, 0) as '% LTE1800_SCC1',	ISNULL(pctTech.pctLTE_800_SCC1, 0) as '% LTE800_SCC1',	

	-- Como no se calculan de momento a null todas - a medida que se activen se calcularan y añadiran sin necesidad de tirar tabla final y recalcular
	null as '% LTE2600_SCC2', null as '% LTE1800_SCC2', null as '% LTE800_SCC2',	null as '% LTE2600_SCC3', null as '% LTE1800_SCC3', null as '% LTE800_SCC3',	null as '% LTE2600_SCC4', null as '% LTE1800_SCC4', null as '% LTE800_SCC4',
	null as '% LTE2600_SCC5', null as '% LTE1800_SCC5', null as '% LTE800_SCC5',	null as '% LTE2600_SCC6', null as '% LTE1800_SCC6', null as '% LTE800_SCC6',	null as '% LTE2600_SCC7', null as '% LTE1800_SCC7', null as '% LTE800_SCC7',

	-- INFO RADIO: 
	tri.longitude as 'Longitud Inicial',	tri.latitude as 'Latitud Inicial',	
	trf.longitude as 'Longitud Final',		trf.latitude as 'Latitud Final',

	--@DGP: KPIS CEM
	pdp.PDP_Activate_Ratio,
	pag.Paging_Success_Ratio,
	neigh.EARFCN_N1,
	neigh.PCI_N1,
	neigh.RSRP_N1,
	neigh.RSRQ_N1,
	ho4G.num_HO_S1X2,
	ho4G.duration_S1X2_avg,
	ho4G.S1X2HO_SR,
	f.IMSI
	
--into Lcc_Data_Latencias
from 
	FileList f,	Sessions s, 
	TestInfo t
		LEFT OUTER JOIN _TECH_RADIO_INI_Data tri		on (t.SessionId=tri.SessionId and t.TestId=tri.testid)
		LEFT OUTER JOIN _TECH_RADIO_FIN_Data trf		on (t.SessionId=trf.SessionId and t.TestId=trf.testid)
		LEFT OUTER JOIN _TECH_RADIO_AVG_Data tra		on (t.SessionId=tra.SessionId and t.TestId=tra.testid)
		LEFT OUTER JOIN _PCT_TECH_Data pctTech			on (pctTech.TestId=t.TestId and pctTech.SessionId=t.SessionId)
		LEFT OUTER JOIN _lcc_http_latencias _lat_kpiid	on (_lat_kpiid.SessionId=t.SessionId and _lat_kpiid.TestId=t.TestId)

	-- KPI EXTRA:
		LEFT OUTER JOIN _PDP pdp			on pdp.TestId=t.TestId and pdp.SessionId=t.SessionId
		LEFT OUTER JOIN _Paging pag			on pag.TestId=t.TestId and pag.SessionId=t.SessionId
		LEFT OUTER JOIN _NEIGH neigh		on neigh.TestId=t.TestId and neigh.SessionId=t.SessionId
		LEFT OUTER JOIN _4GHO ho4G			on ho4G.TestId=t.TestId and ho4G.SessionId=t.SessionId	
where 
	t.SessionId=s.SessionId and s.FileId=f.FileId
	and s.sessionType='data' 
	and t.typeoftest='Ping'
	and t.valid=1 and s.valid=1 
	
	and _lat_kpiid.size=@sizePing

	and t.testid > @maxTestid_LAT
	and RIGHT(LEFT(f.IMSI,5),2) in (1,7,3,4)
order by f.FileId, t.SessionId, t.TestId	

select 'Fin creacion tabla Lcc_Data_Latencias' info




---- (6)
---- *************************************
---- ACTUALIZACION MUESTRAS GPS	  ----
---- *************************************

--DGP 27/11/2015: Se actualizan los campos sin GPS, con la posición válida más cercana en el tiempo.
--DGP 07/03/2016: Se hacía hacia adelante en el tiempo, se añade ahora hacia atrás por si se da al final
-- ******************************************************************************************************

-- GPS parte Inicial Hacia Adelante en el tiempo
update Lcc_Data_HTTPTransfer_DL

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime)
from Lcc_Data_HTTPTransfer_DL lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_DL

update Lcc_Data_HTTPTransfer_UL

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime)
from Lcc_Data_HTTPTransfer_UL lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_UL

update Lcc_Data_HTTPBrowser

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime)
from Lcc_Data_HTTPBrowser lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_BR

update Lcc_Data_Latencias

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime)
from Lcc_Data_Latencias lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_LAT

update Lcc_Data_Youtube

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime)
from Lcc_Data_Youtube lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_YTB


-- GPS parte Inicial Hacia Atras en el tiempo
update Lcc_Data_HTTPTransfer_DL

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc)
from Lcc_Data_HTTPTransfer_DL lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_DL

update Lcc_Data_HTTPTransfer_UL

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc)
from Lcc_Data_HTTPTransfer_UL lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_UL

update Lcc_Data_HTTPBrowser

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc)
from Lcc_Data_HTTPBrowser lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_BR

update Lcc_Data_Latencias

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc)
from Lcc_Data_Latencias lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_LAT

update Lcc_Data_Youtube

set [longitud Inicial]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc),
	[latitud Inicial]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.startTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.startTime desc)
from Lcc_Data_Youtube lc
where
(lc.[longitud Inicial] is null or lc.[longitud Inicial]=0)
and lc.testid > @maxTestid_YTB


-- GPS parte Final Hacia Adelante en el tiempo
update Lcc_Data_HTTPTransfer_DL

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime)
from Lcc_Data_HTTPTransfer_DL lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_DL

update Lcc_Data_HTTPTransfer_UL

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime)
from Lcc_Data_HTTPTransfer_UL lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_UL

update Lcc_Data_HTTPBrowser

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime)
from Lcc_Data_HTTPBrowser lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_BR

update Lcc_Data_Latencias

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime)
from Lcc_Data_Latencias lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_LAT

update Lcc_Data_Youtube

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink>=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime)
from Lcc_Data_Youtube lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_YTB


-- GPS parte Final Hacia Atras en el tiempo
update Lcc_Data_HTTPTransfer_DL

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc)
from Lcc_Data_HTTPTransfer_DL lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_DL

update Lcc_Data_HTTPTransfer_UL

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc)
from Lcc_Data_HTTPTransfer_UL lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_UL

update Lcc_Data_HTTPBrowser

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc)
from Lcc_Data_HTTPBrowser lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_BR

update Lcc_Data_Latencias

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc)
from Lcc_Data_Latencias lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_LAT

update Lcc_Data_Youtube

set [longitud Final]=(select top 1 longitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc),
	[latitud Final]=(select top 1 latitude from lcc_timelink_position 
						where timelink<=master.dbo.fn_lcc_gettimelink(lc.endTime)
						and collectionname=lc.collectionname
						and side='A'
						order by lc.endTime desc)
from Lcc_Data_Youtube lc
where
(lc.[longitud Final] is null or lc.[longitud Final]=0)
and lc.testid > @maxTestid_YTB


---- (7)
---- *************************************
----		INVALIDACIONES VARIAS	  ----
---- *************************************

-- ************************************************************************************************************
-- DGP 09/09/2015:
-- ******************* Invalidación de errores de Herramienta *************************************************
----------------
update testinfo
set valid=0, invalidReason='LCC UEServer Issues'
where testid in (	
					select testid from lcc_data_HTTPTransfer_DL
					where errorcause in ('Error: Measurement abort','Error: Reference file not found',
					'Error: Exception', 'Error: Browser Navigation Error: INET_E_RESOURCE_NOT_FOUND',
					'Error: HTTP: Service unavailable')
						and testid > @maxTestid_DL

					union all

					select testid from lcc_data_HTTPTransfer_UL
					where errorcause in ('Error: Measurement abort','Error: Reference file not found',
					'Error: Exception', 'Error: Browser Navigation Error: INET_E_RESOURCE_NOT_FOUND',
					'Error: HTTP: Service unavailable')
						and testid > @maxTestid_UL

					union all

					select testid from lcc_data_HTTPBrowser
					where errorcause in ('Error: Measurement abort','Error: Reference file not found',
					'Error: Exception', 'Error: Browser Navigation Error: INET_E_RESOURCE_NOT_FOUND',
					'Error: HTTP: Service unavailable')		
						and testid > @maxTestid_BR	
				)

-- ************************************************************************************************************
-- DGP 08/10/2015:
-- ******************* Invalidación de tests no marcados como completados *************************************
--------------
update testinfo
set valid=0, invalidReason='LCC Not Completed Test'
where testid in (	
					select testid from lcc_data_HTTPTransfer_DL
					where info <> 'Completed'
					and testid > @maxTestid_DL

					union all

					select testid from lcc_data_HTTPTransfer_UL
					where info <> 'Completed'
					and testid > @maxTestid_UL

					union all

					select testid from lcc_data_HTTPBrowser
					where info <> 'Completed'	
					and testid > @maxTestid_BR
					
					union all

					select testid from Lcc_Data_Latencias
					where info <> 'Completed'
					and testid > @maxTestid_LAT
					
					union all

					select testid from Lcc_Data_YOUTUBE
					where info <> 'Completed'	
					and testid > @maxTestid_YTB	
				)

-- ************************************************************************************************************
-- DGP 14/10/2015:
-- ************** Invalidación de tests Youtube con Freeze tras descargar el video completo *******************
----------------
update testinfo
set valid=0, Invalidreason=Invalidreason+' || LCC - Freezing after DL Time'
where testid in
		(select y.testid
			from [ResultsVq06TimeDom] y
			left outer join ResultsKpi r on r.sessionid=y.sessionid and r.testid=y.testid and r.kpiid=20625
			where y.sessionid=r.sessionid
			and y.testid=r.testid
			and y.degtime > r.duration
			and y.deltatime > (select settings from SQGeneralSettings where settingID=13)
			and y.testid > @maxTestid_YTB	
			group by y.testid)

-- ************************************************************************************************************
-- DGP 04/11/2015:
-- ************** Anulamos todos los valores temporales en el caso de errores *********************
--------------
update Lcc_Data_HTTPTransfer_DL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null
where  errortype is not null
and info='completed'
and testid > @maxTestid_DL

update Lcc_Data_HTTPTransfer_UL
set DataTransferred=null,  TransferTime=null, Throughput=null, [IP Access Time (ms)]=null
where  errortype is not null
and info='completed'
and testid > @maxTestid_UL

update lcc_data_httpBrowser
set [IP Service Setup Time (s)]=null,	[Transfer Time (s)]=null,	[Session Time (s)]=null,	[DNS Resolution (s)]=null
where errortype is not null
and info='completed'
and testid > @maxTestid_BR



-- ************************************************************************************************************
-- DGP 10/11/2015:
-- ************** Convertimos a completadas los tests marcados como fallo erróneamente ************************
----------------
exec sp_lcc_dropifexists '_VALIDABLE_WEB'		
select
	b.testid,
	case
		when b.errorcause is null then 0
		   when b.errorcause like '%timeout%' and isnull(r.num_ok,0)>=75 and b.testtype like 'Kepl%' and b.session_time_sec_nu<10 and isnull(r.num_rst,0)=0 then 1
		   when b.errorcause like '%timeout%' and isnull(r.num_ok,0)>=22 and b.testtype like 'Mobile%' and b.session_time_sec_nu<10 and isnull(r.num_rst,0)=0 then 1
		   else 0
	end as validable_test
into _VALIDABLE_WEB
from lcc_data_httpBrowser b
	left outer join (
						select testid,
							   sum(case when msg like '80%RST%' then 1 else 0 end) as num_rst,
							   sum(case when msg='HTTP/1.1 200 OK' then 1 else 0 end) as num_ok
						from msgethereal 
						where testid > @maxTestid_BR
						group by testid
	) r on r.testid=b.testid
where b.errorcause like '%timeout%'
and b.testid > @maxTestid_BR

----------------
-- Nos vale volver a coger los valores de _nu porque para BROW se usan los KPIID en ambos metodos
update lcc_data_httpbrowser
set [DataTransferred]=b.[DataTransferred_nu],
	[ErrorCause]=null,
	[ErrorType]=null,
	[Throughput]=b.[ThputApp_nu],
	[IP Service Setup Time (s)]=b.[IP_AccessTime_sec_nu],
	[Transfer Time (s)]=b.[Transfer_Time_sec_nu],
	[Session Time (s)]=b.[Session_Time_sec_nu],
	[DNS Resolution (s)]=b.[DNSTime_nu]
from lcc_data_httpBrowser b,
	_VALIDABLE_WEB r
where b.info='completed'
	and r.testid=b.testid and r.validable_test=1
	and b.testid > @maxTestid_BR


-- ************************************************************************************************************
-- DGP 12/11/2015:
-- ***************** Invalidamos los tests marcados como fallo por timeout erróneamente ***********************
----------------
update testinfo
set valid=0, invalidReason='LCC UL Wrong Timeout'
where testid in (
select testid from lcc_data_httpTransfer_UL
where errorcause like '%timeout%'
	and datatransferred_nu=1024000		-- El _nu corresponde al método antiguo
	and sessiontime_nu <21
	and testtype='UL_CE'
	and testid > @maxTestid_UL)


-- ************************************************************************************************************
--DGP 20/01/2015:
-- *********************** Invalidamos los tests de Main o Smaller fuera de contorno **************************
----------------
if (db_name() like '%main%' or db_name() like '%smaller%')
begin

--------------
update testinfo
set valid=0, invalidReason='LCC OutOfBounds'
where testid in (
	select d.testid from lcc_data_httpTransfer_DL d, agrids.dbo.lcc_parcelas lp
	where lp.nombre=master.dbo.fn_lcc_getParcel(d.[Longitud Final], d.[Latitud Final])
	and (entorno not like '[0-9]%' and entorno not like 'LA [0-9]%')
	and d.testid > @maxTestid_DL
	)
and valid=1

update testinfo
set valid=0, invalidReason='LCC OutOfBounds'
where testid in (
	select u.testid from lcc_data_httpTransfer_UL u, agrids.dbo.lcc_parcelas lp
	where lp.nombre=master.dbo.fn_lcc_getParcel(u.[Longitud Final], u.[Latitud Final])
	and (entorno not like '[0-9]%' and entorno not like 'LA [0-9]%')
	and u.testid > @maxTestid_UL
	)
and valid=1

update testinfo
set valid=0, invalidReason='LCC OutOfBounds'
where testid in (
	select b.testid from lcc_data_httpBrowser b, agrids.dbo.lcc_parcelas lp
	where lp.nombre=master.dbo.fn_lcc_getParcel(b.[Longitud Final], b.[Latitud Final])
	and (lp.entorno not like '[0-9]%' and lp.entorno not like 'LA [0-9]%')
	and b.testid > @maxTestid_BR
	)
and valid=1

update testinfo
set valid=0, invalidReason='LCC OutOfBounds'
where testid in (
	select y.testid from Lcc_Data_YOUTUBE y, agrids.dbo.lcc_parcelas lp
	where lp.nombre=master.dbo.fn_lcc_getParcel(y.[Longitud Final], y.[Latitud Final])
	and (lp.entorno not like '[0-9]%' and lp.entorno not like 'LA [0-9]%')
	and y.testid > @maxTestid_YTB
	)
and valid=1

update testinfo
set valid=0, invalidReason='LCC OutOfBounds'
where testid in (
	select l.testid from Lcc_Data_Latencias l, agrids.dbo.lcc_parcelas lp
	where lp.nombre=master.dbo.fn_lcc_getParcel(l.[Longitud Final], l.[Latitud Final])
	and (lp.entorno not like '[0-9]%' and lp.entorno not like 'LA [0-9]%')
	and l.testid > @maxTestid_LAT
	)
and valid=1

end


-- ************************************************************************************************************
-- ERC 03/01/2016:
-- **************************** Invalidamos los tests con Error Code Import<>0 *********************************
----------------
-- Se invalidan los test cuyos KPIID no pueden calcularse por tener fallido el trigger, pero el test se esta dando como valido
update testinfo
set valid=0, invalidReason=invalidReason + ' || LCC Start/End Time missing (at Session/Test end)'
from testinfo t, lcc_data_httpTransfer_DL h
where t.testid=h.testid	
	and h.ErrorCause='Error: Start/End Time missing (at Session/Test end)'
	and t.InvalidReason not like '%|| LCC Start/End Time missing (at Session/Test end)'		-- Por no añadir la causa en reprocesados
	and t.testid>@maxTestid_DL

update testinfo
set valid=0, invalidReason=invalidReason + ' || LCC Start/End Time missing (at Session/Test end)'
from testinfo t, lcc_data_httpTransfer_UL h
where t.testid=h.testid	
	and h.ErrorCause='Error: Start/End Time missing (at Session/Test end)'
	and t.InvalidReason not like '%|| LCC Start/End Time missing (at Session/Test end)'		-- Por no añadir la causa en reprocesados
	and t.testid>@maxTestid_UL

update testinfo
set valid=0, invalidReason=invalidReason + ' || LCC Start/End Time missing (at Session/Test end)'
from testinfo t, Lcc_Data_HTTPBrowser h
where t.testid=h.testid	
	and h.ErrorCause='Error: Start/End Time missing (at Session/Test end)'
	and t.InvalidReason not like '%|| LCC Start/End Time missing (at Session/Test end)'		-- Por no añadir la causa en reprocesados
	and t.testid>@maxTestid_BR


-- ************************************************************************************************************
-- DGP 18/02/2016:
-- *********************** Invalidamos los tests afectados por el URA PCH **************************
exec dbo.sp_lcc_DropIfExists '_URAstate'

select tant.msgtime as initime,t.msgtime as endtime, 
	        tant.rrcstate as rrcstate, t.rrcstate as newRrcState,
			tnext.rrcstate as next_RRCState, tnext.msgtime as nextRRC_time
,s.fileid as fileid 
into _URAstate 
from wcdmarrcstate t, wcdmarrcstate tant, wcdmarrcstate tnext, sessions s, sessions sant, sessions snext
where t.sessionid=s.sessionid and tant.sessionid=sant.sessionid and tnext.sessionid=snext.sessionid
and s.fileid=sant.fileid and s.fileid=snext.FileId
and t.MsgId=tant.MsgId+1 and t.MsgId=tnext.msgid-1
and s.sessionid > @maxSessionid

------------------------------
exec dbo.sp_lcc_DropIfExists '_URA'

select t.*, datediff(s,r.initime,t.starttime) timeInRRCstate,r.rrcstate, 
r.newRRCState, datediff(s,t.starttime,r.endtime) timeToRRCstate_Change,
1 as samples
into _URA
from
(
	select 
	 master.dbo.fn_lcc_getElement(4,collectionname,'_') city
	,CollectionName,imei,mnc,starttime,endtime,sessionid,testid,fileid,
	testtype,errorcause,errortype,info
	from [dbo].[Lcc_Data_HTTPBrowser]
	union all
	select master.dbo.fn_lcc_getElement(4,collectionname,'_') city
	,CollectionName,imei,mnc,starttime,endtime,sessionid,testid,fileid,
	testtype,errorcause,errortype,info
	 from [dbo].[Lcc_Data_HTTPTransfer_DL]
	 union all
	select master.dbo.fn_lcc_getElement(4,collectionname,'_') city
	,CollectionName,imei,mnc,starttime,endtime,sessionid,testid,fileid,
	testname testtype,fails errorcause, cause errortype,info 
	from [dbo].[Lcc_Data_YOUTUBE]
	union all
	select 
	master.dbo.fn_lcc_getElement(4,collectionname,'_') city
	,CollectionName,imei,mnc,starttime,endtime,sessionid,testid,fileid,
	testtype,errorcause,errortype,info 
	from [dbo].[Lcc_Data_HTTPTransfer_UL] 
) t
left outer join _URAstate r 
   on t.fileid=r.fileid
      and t.startTime between r.initime and r.endtime
------------------------

	update testinfo
	set valid=0, invalidreason='LCC_URAPCH_Issue'
	from testinfo t, _URA i
	where i.rrcstate=5 and i.timeToRRCstate_Change>=10
	and i.errortype is not null
	and t.testid=i.testid
	and t.sessionid > @maxSessionid
	and t.valid=1


--DGP 11/03/2016:
-- *********************** Ponemos a NULL la info de Radio de los tests en los que no exista esa info **************************

update Lcc_Data_HttpTransfer_DL 

set [% GSM]=null, [% WCDMA]=null, [% LTE]=null, [% F1 U2100]=null, [% F2 U2100]=null, [% F3 U2100]=null, [% F1 U900]=null,
	[% F2 U900]=null, [% F1 L2600]=null, [% F1 L2100]=null, [% F2 L2100]=null, [% F1 L1800]=null, [% F2 L1800]=null,
	[% F3 L1800]=null, [% F1 L800]=null, [% U2100]=null, [% U900]=null, [% LTE2600]=null, [% LTE2100]=null, [% LTE1800]=null,
	[% LTE800]=null, [DCS %]=null, [GSM %]=null, [EGSM %]=null, [% LTE2600_SCC1]=null, [% LTE1800_SCC1]=null, [% LTE800_SCC1]=null
where
 ([% GSM] = 0 and [% WCDMA]=0 and [% LTE]=0)
and testid > @maxTestid_DL

update Lcc_Data_HttpTransfer_UL

set [% GSM]=null, [% WCDMA]=null, [% LTE]=null, [% F1 U2100]=null, [% F2 U2100]=null, [% F3 U2100]=null, [% F1 U900]=null,
	[% F2 U900]=null, [% F1 L2600]=null, [% F1 L2100]=null, [% F2 L2100]=null, [% F1 L1800]=null, [% F2 L1800]=null,
	[% F3 L1800]=null, [% F1 L800]=null, [% U2100]=null, [% U900]=null, [% LTE2600]=null, [% LTE2100]=null, [% LTE1800]=null,
	[% LTE800]=null, [DCS %]=null, [GSM %]=null, [EGSM %]=null
	--, [% LTE2600_SCC1]=null, [% LTE1800_SCC1]=null, [% LTE800_SCC1]=null
where
 ([% GSM] = 0 and [% WCDMA]=0 and [% LTE]=0)
and testid > @maxTestid_UL

update Lcc_Data_HttpBrowser

set [% GSM]=null, [% WCDMA]=null, [% LTE]=null, [% F1 U2100]=null, [% F2 U2100]=null, [% F3 U2100]=null, [% F1 U900]=null,
	[% F2 U900]=null, [% F1 L2600]=null, [% F1 L2100]=null, [% F2 L2100]=null, [% F1 L1800]=null, [% F2 L1800]=null,
	[% F3 L1800]=null, [% F1 L800]=null, [% U2100]=null, [% U900]=null, [% LTE2600]=null, [% LTE2100]=null, [% LTE1800]=null,
	[% LTE800]=null, [DCS %]=null, [GSM %]=null, [EGSM %]=null, [% LTE2600_SCC1]=null, [% LTE1800_SCC1]=null, [% LTE800_SCC1]=null
where
 ([% GSM] = 0 and [% WCDMA]=0 and [% LTE]=0)
and testid > @maxTestid_BR

update Lcc_Data_Youtube

set [% GSM]=null, [% WCDMA]=null, [% LTE]=null, [% F1 U2100]=null, [% F2 U2100]=null, [% F3 U2100]=null, [% F1 U900]=null,
	[% F2 U900]=null, [% F1 L2600]=null, [% F1 L2100]=null, [% F2 L2100]=null, [% F1 L1800]=null, [% F2 L1800]=null,
	[% F3 L1800]=null, [% F1 L800]=null, [% U2100]=null, [% U900]=null, [% LTE2600]=null, [% LTE2100]=null, [% LTE1800]=null,
	[% LTE800]=null, [DCS %]=null, [GSM %]=null, [EGSM %]=null, [% LTE2600_SCC1]=null, [% LTE1800_SCC1]=null, [% LTE800_SCC1]=null
where
 ([% GSM] = 0 and [% WCDMA]=0 and [% LTE]=0)
and testid > @maxTestid_YTB


update Lcc_Data_Latencias

set [% GSM]=null, [% WCDMA]=null, [% LTE]=null, [% F1 U2100]=null, [% F2 U2100]=null, [% F3 U2100]=null, [% F1 U900]=null,
	[% F2 U900]=null, [% F1 L2600]=null, [% F1 L2100]=null, [% F2 L2100]=null, [% F1 L1800]=null, [% F2 L1800]=null,
	[% F3 L1800]=null, [% F1 L800]=null, [% U2100]=null, [% U900]=null, [% LTE2600]=null, [% LTE2100]=null, [% LTE1800]=null,
	[% LTE800]=null, [DCS %]=null, [GSM %]=null, [EGSM %]=null, [% LTE2600_SCC1]=null, [% LTE1800_SCC1]=null, [% LTE800_SCC1]=null
where
 ([% GSM] = 0 and [% WCDMA]=0 and [% LTE]=0)
and testid > @maxTestid_LAT


--DGP 16/03/2016
-- *********************** Se invalidan todos los tests en los que ningun KPIID tiene duración **************************

update testinfo
set valid=0, invalidReason = 'LCC Youtube Null Test'

from testinfo t, _ETSIYouTubeKPIs e

where t.testid=e.testid
		and	(e.Duration10620 is null 
			and e.Duration20620 is null
			and e.Duration10625 is null
			and e.Duration30621 is null
			and e.Duration20621 is null)
and t.valid=1
and t.testid > @maxTestid




--****************************************************************************************************
-- ******************************		 BORRADO de Tablas intermedias	******************************
--****************************************************************************************************
------------------
-- Tablas antiguas:
drop table 
	#maxTestID, _URAstate, _URA,
	dbo._PCT_TECH_Data, 
	dbo._CQI_3G, dbo._CQI_4G, dbo._HARQ, _VALIDABLE_WEB,
	dbo._MOD_3G, dbo._MOD_4G, dbo._PUCCHCQI_4G, dbo._RBs_carrier_DL, dbo._RBs_DL, dbo._RBs_UL, 
	dbo._SCC_CQI, dbo._SCCH_USE_3G, dbo._SCCH_USE_4G, dbo._SF, dbo._SHOs, 
	dbo._ULMAC, dbo._TM_DL, dbo._TM_UL,dbo._tSF,
	dbo._THPUT,
	dbo._THPUT_RLC, dbo._THPUT_Transf,  dbo._ETSIYouTubeKPIs,
	_TECH_RADIO_AVG_Data, _TECH_RADIO_DURATION_Data, _TECH_RADIO_FIN_Data,
	_TECH_RADIO_INI_Data, _lcc_Serving_Cell_Table_duration_Data,
	_tempStateRCC, _stateRCC, _UL_Int, _BW_RADIO_DURATION_Data, _lcc_BandWidth_Table_duration_Data

----------------
-- Nuevos KPIID:
drop table 
	_lcc_gets, _lcc_200, _lcc_ip_service, 
	_lcc_ResultsKPI, 
	_lcc_http_browser, _lcc_http_DL, _lcc_http_latencias, _lcc_http_UL, _lcc_ResultsKPI_DNSTime,		--,_lcc_http_youtube
	
	_PDP, _Paging, _NEIGH, _4GHO, _Window, _Buffer



GO

