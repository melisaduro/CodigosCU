USE FY1617_Data_Rest_4G_H2_5
select f.fileid, sessionid, collectionname
from filelist f, sessions s
where collectionname like '%calatayud%'
and f.fileid=s.fileid
order by sessionid asc, fileid asc

USE FY1617_Voice_Rest_4G_H2_7
select f.fileid, sessionid, collectionname
from filelist f, sessions s
where collectionname like '%calatayud%'
and f.fileid=s.fileid
order by sessionid asc, fileid asc


use FY1617_Voice_Rest_4G_H2_7
declare @misession as float
declare @mifileid as float
set @misession = 38735 --/ PON AQUI LA SESSION MINIMA A BORRAR /
set @mifileid = 291
/* Voz*/
begin transaction

delete 
from [dbo].lcc_position
where sessionid >= @misession

delete
from [dbo].lcc_timelink_position
where fileid >= @mifileid

delete 
from [dbo].[lcc_Serving_Cell_Table]
where sessionid >= @misession

delete 
from [dbo].[lcc_markers_time]
where sessionid >= @misession

delete 
from [dbo].[lcc_Calls_Detailed]
where sessionid >= @misession
commit


use FY1617_Voice_Rest_4G_H2_7
declare @misession as float
declare @mifileid as float
set @misession = 38735 --/ PON AQUI LA SESSION MINIMA A BORRAR /
set @mifileid = 291
/*Scanner*/
delete 
from [dbo].[lcc_scannerWcdma]
where sessionid >= @misession

delete 
from [dbo].lcc_Scanner_LTE_Detailed
where sessionid >= @misession

delete 
from [dbo].lcc_Scanner_UMTS_Detailed
where sessionid >= @misession

delete 
from [dbo].lcc_Scanner_GSM_Detailed
where sessionid >= @misession

--delete 
--from [dbo].lcc_Scanner_LTE_Detailed
--where sessionid >= @misession

--delete 
--from [dbo].lcc_GSMScanner_allFreqs_allBCCH_50x50_probCobIndoor_ord
--where fileid >= @mifileid

--delete 
--from [dbo].lcc_GSMScanner_allFreqs_allBCCH_50x50_probCobIndoor
--where fileid >= @mifileid

--select *
--from [dbo].lcc_GSMScanner_allFreqs_allBCCH_50x50_probCobIndoor_LastFileid

--delete 
--from [dbo].lcc_UMTSScanner_allFreqs_allSC_50x50_probCobIndoor_ord
--where fileid >= @mifileid

--delete 
--from [dbo].lcc_UMTSScanner_allFreqs_allSC_50x50_probCobIndoor
--where fileid >= @mifileid

--select *
--from [dbo].lcc_UMTSScanner_allFreqs_allSC_50x50_probCobIndoor_LastFileid

--delete 
--from [dbo].lcc_LTEScanner_allFreqs_allPCIS_50x50_probCobIndoor
--where fileid >= @mifileid

--delete 
--from [dbo].lcc_LTEScanner_allFreqs_allPCIS_50x50_probCobIndoor_ord
--where fileid >= @mifileid

--select *
--from [dbo].lcc_LTEScanner_allFreqs_allPCIS_50x50_probCobIndoor_LastFileid


use FY1617_Data_Rest_4G_H2_5
declare @misession as float
declare @mifileid as float
set @misession = 3808
set @mifileid = 137
begin transaction
/* Datos*/
delete 
from [dbo].lcc_position
where sessionid >= @misession

delete
from [dbo].lcc_timelink_position
where fileid>= @mifileid

delete 
from [dbo].[lcc_Serving_Cell_Table]
where sessionid >= @misession

delete 
from [dbo].[Lcc_Data_HTTPBrowser]
where sessionid >= @misession

delete 
from [dbo].[Lcc_Data_HTTPTransfer_DL]
where sessionid >= @misession

delete 
from [dbo].[Lcc_Data_HTTPTransfer_UL]
where sessionid >= @misession

delete 
from [dbo].[Lcc_Data_Latencias]
where sessionid >= @misession

delete 
from [dbo].[lcc_data_Youtube]
where sessionid >= @misession

delete 
from [dbo].[lcc_Physical_Info_Table]
where sessionid >= @misession
commit