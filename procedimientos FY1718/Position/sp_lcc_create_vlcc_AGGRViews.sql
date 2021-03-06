USE FY1718_Voice_Rest_4G_H1_22
--GO
--/****** Object:  StoredProcedure [dbo].[sp_lcc_create_vlcc_AGGRViews]    Script Date: 30/08/2017 10:52:45 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

			 
--ALTER procedure [dbo].[sp_lcc_create_vlcc_AGGRViews] as

--*************************************************************************

--	1) [vlcc_AGGRVoice3G]	-	[AGGRVoice3G]
--	2) [vlcc_AGGRVoice4G]	-	[AGGRVoice4G] y [AGGRVoice4G_ROAD]				
--	3) [vlcc_AGGRData3G]	-	[AGGRData3G]
--	4) [vlcc_AGGRData4G]	-	[AGGRData4G] y [AGGRData4G_ROAD]
--  5) [vlcc_AGGRVolte]		-	[AGGRVOLTE]

-- MDM: se añaden a las bases de datos de voz 4G-> [vlcc_AGGRVoice4G] y [vlcc_AGGRVolte]

--*************************************************************************

--------------------------------------------	VOZ 3G
if db_name() like '%Voice%3G%'
begin
	--	1) vlcc_AGGRVoice3G
	If (select name from sys.views where name = 'vlcc_AGGRVoice3G') is null
	begin
		exec ('
		--CREATE VIEW [dbo].[vlcc_AGGRVoice3G] AS
		SELECT 
			 [Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		FROM [AGGRVoice3G].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		')
	end
end

--------------------------------------------	VOZ 4G

if db_name() like '%Voice%4G%' or db_name() like '%Voice_AVE%' or 
	db_name() like '%Voice_Indoor%' or db_name() like '%Voice_MRoad_A%'	-- este ultimo termina en _A, para diferenciar de VOLTE
	and db_name() not like '%1718%'
begin
	--	2) vlcc_Estads_M2M
	If (select name from sys.views where name = 'vlcc_AGGRVoice4G') is null
	begin
		exec ('
			CREATE VIEW [dbo].[vlcc_AGGRVoice4G] AS
			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]

			union all

			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVoice4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
		')
	end
end 


--------------------------------------------	DATOS 3G
if db_name() like '%Data%3G%'
begin
	--	3) vlcc_AGGRData3G
	If (select name from sys.views where name = 'vlcc_AGGRData3G') is null
	begin
		exec('
		CREATE VIEW [dbo].[vlcc_AGGRData3G] AS
		SELECT 
			 [Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		FROM [AGGRData3G].[dbo].[lcc_aggr_sp_MDD_Data_All_Test]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		')
	end
end 


--------------------------------------------	DATOS 4G
if db_name() like '%Data%4G%' or db_name() like '%Data_AVE%' or 
	db_name() like '%Data_Indoor%' or db_name() like '%Data_MRoad_A%'
begin
	--	4) vlcc_AGGRData4G	
	If (select name from sys.views where name = 'vlcc_AGGRData4G') is null
	begin
		exec('
		CREATE VIEW [dbo].[vlcc_AGGRData4G] AS
		SELECT 
			 [Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		FROM [AGGRData4G].[dbo].[lcc_aggr_sp_MDD_Data_All_Test]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]

		union all

		SELECT 
			 [Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type],''4G'' as [Tech]
		FROM [AGGRData4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Data_All_Test]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		')
	end
end


--------------------------------------------	VOLTE
if db_name() like '%VOLTE%'
begin
	--	4) vlcc_AGGRVolte
	If (select name from sys.views where name = 'vlcc_AGGRVolte') is null
	begin
		exec('
		CREATE VIEW [dbo].[vlcc_AGGRVolte] AS
		SELECT 
			[Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		FROM [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]

		union all

		SELECT 
			[Database]		,[mnc]      
			,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
			,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		FROM [AGGRVOLTE_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
		group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
			,[Report_Type]	,[Aggr_Type]
		')
	end
end

--------------------------------------------	VOZ 4G + VOLTE (METOLOGIA FY1718)     
-------------------------------------------- Consultamos tanto el agregado de voz como el de VOLTE ya que se agrega tanto voz como VOLTE en la misma base de datos

if db_name() like '%Voice%4G%' or db_name() like '%Voice_AVE%' or 
	db_name() like '%Voice_Indoor%' or db_name() like '%Voice_MRoad_A%'	-- este ultimo termina en _A, para diferenciar de VOLTE
	and db_name() like '%1718%'
begin
	--	2) vlcc_Estads_M2M
	If (select name from sys.views where name = 'vlcc_AGGRVoice4G') is null
	begin
		exec ('
			CREATE VIEW [dbo].[vlcc_AGGRVoice4G] AS
			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVoice4G].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]

			union all

			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVoice4G_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
		')
	end

	--	2) vlcc_Estads_M2M
	If (select name from sys.views where name = 'vlcc_AGGRVolte') is null
	begin
		exec ('
			CREATE VIEW [dbo].[vlcc_AGGRVolte] AS
			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVOLTE].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]

			union all

			SELECT 
				 [Database]		,[mnc]      
				,[Meas_Week]    ,[Meas_Round]	,[Meas_Date]
				,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]
				,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
			FROM [AGGRVOLTE_ROAD].[dbo].[lcc_aggr_sp_MDD_Voice_Llamadas]
			group by 	[Database]      ,[mnc]     ,[Meas_Week]    ,[Meas_Round]   ,[Meas_Date]	,[Entidad]		,[Region_VF]--,[Region_OSP]
				,[Num_Medida]	,[Key_Fields]	,[Date_Reporting]	,[Week_Reporting]
				,[Report_Type]	,[Aggr_Type]
		')
	end
end 


--------------------------------------------	COVERAGE
if db_name() like '%OSP%coverage%' or
	db_name() like '%voice%'
begin
	--	5) vlcc_AGGRcoverage
	If (select name from sys.views where name = 'vlcc_AGGRcoverage') is null
	begin
		exec('CREATE VIEW [dbo].[vlcc_AGGRcoverage] AS
		select   
			 [Database]		,[mnc]				
			,[Meas_Week]	,[Meas_Round]	,[Meas_Date]
			,[Entidad]      ,[Region_VF]--,[Region_OSP]
			,[Num_Medida]	,[Key_Fields]
			,[Date_Reporting]	,[Week_Reporting]   ,[Report_Type]    ,[Aggr_Type]

		from  [AGGRCoverage].[dbo].[lcc_aggr_sp_MDD_Coverage_All_Curves]

		group by [Database]      ,[mnc]				,[Meas_Week]			,[Meas_Round]		,[Meas_Date]      ,[Entidad]     ,[Region_VF]--,[Region_OSP]      
				,[Num_Medida]    ,[Key_Fields]      ,[Date_Reporting]		,[Week_Reporting]   ,[Report_Type]    ,[Aggr_Type]


				--------------------------------------------------------------------------------------------------------------------------
				--select   [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP]  
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,''2G'' as tech_aggr, p.provincia, p.[Completed]

				--from [AGGRCoverage].[dbo].[lcc_aggr_sp_MDD_Coverage_2G] c, [AddedValue].[dbo].[lcc_provincias_Completed] p
				--where 
				--	c.provincia=p.provincia
				--group by [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP]    
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,p.provincia, p.[Completed]
				-----------
				--union all
				--select   [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP]
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,''3G'' as tech_aggr, p.provincia, p.[Completed]
				--from [AGGRCoverage].[dbo].[lcc_aggr_sp_MDD_Coverage_3G] c, [AddedValue].[dbo].[lcc_provincias_Completed] p
				--where 
				--	c.provincia=p.provincia
				--group by [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP] 
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,p.provincia, p.[Completed]

				-----------
				--union all
				--select  [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP]
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,''4G'' as tech_aggr, p.provincia, p.[Completed]
				--from [AGGRCoverage].[dbo].[lcc_aggr_sp_MDD_Coverage_4G] c, [AddedValue].[dbo].[lcc_provincias_Completed] p
				--where 
				--	c.provincia=p.provincia
				--group by [Database]      ,[mnc]      ,[Meas_Week]      ,[Meas_Round]      ,[Meas_Date]      ,[Entidad]      ,[Region_VF]--,[Region_OSP]
				--		,[Num_Medida]      ,[Key_Fields]      ,[Date_Reporting]      ,[Week_Reporting]      ,[Report_Type]    ,[Aggr_Type]
				--		,p.provincia, p.[Completed]
				--order by entidad
				--------------------------------------------------------------------------------------------------------------------------
		')
	end
end

