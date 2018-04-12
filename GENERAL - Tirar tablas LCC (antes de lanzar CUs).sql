USE [FY1617_Data_AVE_Rest_H1]
select sessionid, collectionname
from filelist f, sessions s
where collectionname like '%bcn-fig-r3%'
and f.fileid=s.fileid
order by sessionid


declare @misession as float
set @misession = 5836 --/ PON AQUI LA SESSION MINIMA A BORRAR /

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

--delete 
--from [dbo].[lcc_Serving_Cell_Table]
--where sessionid >= @misession

--delete 
--from [dbo].[lcc_Physical_Info_Table]
--where sessionid >= @misession