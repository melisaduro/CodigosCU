--use [FY1516_Data_main_4G_q2]
--[FY1516_Data_Smaller_3G_H1]
--[FY1516_DATA_Main_3G_H1_3]
--[FY1516_DATA_Main_3G_H1_2]
--[FY1516_Data_MRoad_A1_Q2]
--[FY1516_Data_MRoad_A7_Q2]
--[FY1516_Data_Main_4G_Q1]
--[FY1516_DATA_Main_4G_Q1_2]
--[FY1516_DATA_Smaller_4G_H1_2]
--[FY1516_Data_Rest_3G_H1]
--[FY1516_Data_Rest_4G_H1]
use [FY1617_Data_MRoad_A3_H2]
-----------------------------------------------------------------------------------------------------------------------
-- Script to create functions for the Layer 3 key value dll
-- Copyright © 2000-2013 SwissQual License AG
-- Date: 	31. January 2013
-- Last change by: R.Kaderli/S.Obi
-----------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- The following script must be executed manually on the master Database (see user manual for L3KeyValue dll)
-----------------------------------------------------------------------------------------------------------------------
     --use master
     --go
     --exec sp_configure 'clr enabled', 1
     --reconfigure
     --go
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------
-- Set the TRUSTWORTHY property of the DB
-----------------------------------------------------------------------------------------------------------------------
DECLARE @dbName varchar(200)
select @dbName = DB_NAME()

DECLARE @q varchar(200)
SET @q = 'Alter Database ' + @dbName + ' SET TRUSTWORTHY ON'
EXEC(@q)

-----------------------------------------------------------------------------------------------------------------------
-- Delete previously created procedures
-----------------------------------------------------------------------------------------------------------------------
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQGSMKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQGSMKeyValue]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQUMTSKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQUMTSKeyValue]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQLTERRCKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQLTERRCKeyValue]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQLTENASKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQLTENASKeyValue]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQKeyValueInit]') and xtype in (N'FS', N'PC')) drop procedure [dbo].[SQKeyValueInit]
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQKeyValueUnload]') and xtype in (N'FS', N'PC')) drop procedure [dbo].[SQKeyValueUnload]
if exists (select * from sys.assemblies where name = 'SQL3KeyValueDotNet') drop Assembly SQL3KeyValueDotNet
GO

-----------------------------------------------------------------------------------------------------------------------
-- Set path to the installation directory of the Layer3 Key Value DLL
-- Example
-- SET @dllPath = 'C:\Program Files\SwissQual\Diversity\L3KeyValue'
-----------------------------------------------------------------------------------------------------------------------
DECLARE @dllPath varchar(200)
SET @dllPath = 'C:\SQL3KeyValue\SQL3KeyValue_V15\L3KeyValue'

Select @dllPath as Path into #tmpPathTable
GO

-----------------------------------------------------------------------------------------------------------------------
-- Bind DLL to Database
-- Update path with the correct location of the dll
-- Example
 --CREATE ASSEMBLY [SQL3KeyValueDotNet]
 --  FROM 'C:\SQL3KeyValue\SQL3KeyValue_V15\L3KeyValue\SQL3KeyValueDotNet_v2.dll'
 --  WITH PERMISSION_SET = UNSAFE
 --GO
-----------------------------------------------------------------------------------------------------------------------
DECLARE @dllPath varchar(200)
Select @dllPath = Path from #tmpPathTable
CREATE ASSEMBLY [SQL3KeyValueDotNet]
  FROM @dllPath + '\SQL3KeyValueDotNet_v2.dll'
  WITH PERMISSION_SET = UNSAFE
GO

-----------------------------------------------------------------------------------------------------------------------
-- Create functions
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Initialization
-- Parameters: @Path:        Path to where the SQL3KeyValueDotNet_v2.dll (@Path does not contain the file name!)
-----------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE SQKeyValueInit @Path nvarchar(max) AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQKeyValueInit
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Unloading dll
-----------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE SQKeyValueUnload AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQKeyValueUnload
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- GSM KeyValue
-- Parameters: @Message:     GSM message (field message of table MsgGSMData/MsgGPRSInterLayerGMMSM)
--             @GSMDataType: 0: GSM L3 Data (parseCode 626 of table MsgGSMData)
--                           1: GPRS GMM/SM (parseCodee 62G1 of table MsgGPRSInterLayerGMMSM)
--                           2: GPRS RLC/MAC (parseCode 62G0 of table MsgGSMData)
--                           3: Channel Request (parseCode 62A of table MsgGSMData) 
--                           4: Packet Channel Request (parseCode 62B of table MsgGSMData) 
--             @KeyValue:    string searching for in the decoded message
-----------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION dbo.SQGSMKeyValue(@Message nvarchar(max), @GSMDataType int, @KeyValue nvarchar(max))
RETURNS nvarchar(max) AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQGSMGetKeyValue
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- UMTS RRC KeyValue
-- Parameters: @Message:     RRC message (field Msg of table WCDMARRCMessages)
--             @LogChnType:  Log channel type (field LogChanType of table WCDMARRCMessages)
--             @MessageType: Name of the message (field msgType of table WCDMARRCMessages) 
--             @KeyValue:    string searching for in the decoded message
-----------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION dbo.SQUMTSKeyValue(@Message nvarchar(max), @LogChanType int, @MessageType nvarchar(max), @KeyValue nvarchar(max))
RETURNS nvarchar(max) AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQUMTSGetKeyValue
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- LTE RRC KeyValue
-- Parameters: @Message:     RRC message (field Msg of table LTERRCMessages)
--             @ChnType:     Channel type (field ChnType of table LTERRCMessages)
--             @KeyValue:    string searching for in the decoded message
-----------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION  dbo.SQLTERRCKeyValue(@Message nvarchar(max), @ChanType int, @KeyValue nvarchar(max))
RETURNS nvarchar(max) AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQLTERRCGetKeyValue
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- LTE NAS KeyValue
-- Parameters: @Message:     NAS message (field Msg of table LTENASMessages)
--             @Direction:   Up or Downlink (field Direction of table LTENASMessages)
--             @KeyValue:    string searching for in the decoded message
-----------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION  dbo.SQLTENASKeyValue(@Message nvarchar(max), @Direction nvarchar(max), @KeyValue nvarchar(max))
RETURNS nvarchar(max) AS
  EXTERNAL NAME SQL3KeyValueDotNet.[SQL3KeyValueDotNet_v2.SQL3KeyValueDotNet_v2].SQLTENASGetKeyValue
GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Calling the SQKeyValueInit
-- This is necessary so the L3 DLL is loaded and can be used by the above functions.
-- !!Important!!
-- This function must be called everytime the SQL Server is restarted for every DB where the assembly is loaded!
-- Example
-- SQKeyValueInit 'C:\Program Files\SwissQual\Diversity\L3KeyValue'
-----------------------------------------------------------------------------------------------------------------------
DECLARE @dllPath varchar(200)
Select @dllPath = Path from #tmpPathTable
EXEC SQKeyValueInit @dllPath
GO

DROP TABLE #tmpPathTable
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Calling the SQKeyValueUnload
-- This is necessary so the L3 DLL can be deleted from the disc without restarting the SQL Server
-- Call this function only if the DLL is no longer used
-----------------------------------------------------------------------------------------------------------------------
-- SQKeyValueUnload
-- GO

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Clean Database from L3 Key Value
-- Call the following functions if the L3 Key Value is no longer used
-----------------------------------------------------------------------------------------------------------------------
-- SQKeyValueUnload
-- GO
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQGSMKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQGSMKeyValue]
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQUMTSKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQUMTSKeyValue]
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQLTERRCKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQLTERRCKeyValue]
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQLTENASKeyValue]') and xtype in (N'FS', N'FN')) drop function [dbo].[SQLTENASKeyValue]
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQKeyValueInit]') and xtype in (N'FS', N'PC')) drop procedure [dbo].[SQKeyValueInit]
-- if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQKeyValueUnload]') and xtype in (N'FS', N'PC')) drop procedure [dbo].[SQKeyValueUnload]
-- if exists (select * from sys.assemblies where name = 'SQL3KeyValueDotNet') drop Assembly SQL3KeyValueDotNet
-- GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


	--use [VDF_FY1516_PRUEBAS]
	--select * from [dbo].[lcc_fachactive]