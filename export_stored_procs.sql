
DECLARE @measure_name NVARCHAR(255) = '2014_ACO_15_PREV_08'
DECLARE @folder_name NVARCHAR(255) = 'ACO_2014'

SET NOCOUNT ON

CREATE TABLE #procs ( name NVARCHAR(255)
						, object_id INT
                        , definition NVARCHAR(MAX)
                        , uses_ansi_nulls BIT
                        , uses_quoted_identifier BIT
                        )
INSERT INTO #procs
SELECT o.name
	 , m.object_id
     , m.definition
     , m.uses_ansi_nulls
     , m.uses_quoted_identifier
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON m.object_id = o.object_id
WHERE o.type = 'P'
	AND o.name like 'EvaluateAll_'+@measure_name+'%'
	
UNION ALL 

SELECT o.name
	 , m.object_id
     , m.definition
     , m.uses_ansi_nulls
     , m.uses_quoted_identifier
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON m.object_id = o.object_id
WHERE o.type = 'P'
	AND o.name like 'EvaluateDenominator_'+@measure_name+'%'	
	
UNION ALL 

SELECT o.name
	 , m.object_id
     , m.definition
     , m.uses_ansi_nulls
     , m.uses_quoted_identifier
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON m.object_id = o.object_id
WHERE o.type = 'P'
	AND o.name like 'EvaluateNumerator_'+@measure_name+'%'	
	
UNION ALL 

SELECT o.name
	 , m.object_id
     , m.definition
     , m.uses_ansi_nulls
     , m.uses_quoted_identifier
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON m.object_id = o.object_id
WHERE o.type = 'P'
	AND o.name like 'EvaluateAutoExclusion_'+@measure_name+'%'			


DECLARE @name nvarchar(255)
	  , @endStmt NCHAR(6)
      , @object_id INT
      , @definition NVARCHAR(MAX)
      , @uses_ansi_nulls BIT
      , @uses_quoted_identifier BIT
      
      
DECLARE @proclist CURSOR
 SET @proclist = CURSOR FOR
 SELECT object_id
     , CHAR(13) + CHAR(10) + 'GO' + CHAR(13) + CHAR(10)
     , name
     , [definition]
 FROM #procs

 OPEN @proclist
 FETCH NEXT
 FROM @proclist INTO @object_id, @endStmt, @name, @definition
 
 WHILE @@FETCH_STATUS = 0
 BEGIN
 
-- Spit out the file name to use

	PRINT '-----------------------------------------------------------------'
	PRINT '--  dbo.'+@name+'.sql'
    PRINT '-----------------------------------------------------------------'
      
-- Add the drop procedure at the top
	
	SELECT @definition = REPLACE(@definition,'CREATE PROCEDURE', 'IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].['+@name+']'') AND type in (N''P'', N''PC''))'+CHAR(13)+CHAR(10)+
		'DROP PROCEDURE [dbo].['+@name+']'+CHAR(13)+CHAR(10)+
		'GO'+CHAR(13)+CHAR(10)+
		'SET ANSI_NULLS ON'+CHAR(13)+CHAR(10)+
		'GO'+CHAR(13)+CHAR(10)+
		'SET QUOTED_IDENTIFIER ON'+CHAR(13)+CHAR(10)+
		'GO'+CHAR(13)+CHAR(10)+
		'CREATE PROCEDURE')
		
    IF LEN(@definition) <= 4000
        PRINT @definition 
    ELSE
    BEGIN
        DECLARE @crlf VARCHAR(2), @len BIGINT, @offset BIGINT, @part BIGINT
        SELECT @crlf = CHAR(13)+CHAR(10)
             , @len = LEN(@definition)
             , @offset = 1
             , @part = CHARINDEX(@crlf,@definition)-1

        WHILE @offset <= @len
        BEGIN
            PRINT SUBSTRING(@definition,@offset,@part)

            SET @offset = @offset + @part + LEN(@crlf)
            SET @part = CHARINDEX(@crlf,@definition,@offset)-@offset  
        END
    END

    PRINT @endStmt


    SELECT @object_id = MIN(object_id)
    FROM #procs
    WHERE object_id > @object_id




 FETCH NEXT
 FROM @proclist INTO @object_id, @endStmt, @name, @definition
 END
 CLOSE @proclist
 --DEALLOCATE @proclist

-- Now spit out the list of files to add to the Perforce list

PRINT '---------------------- F I L E   L I S T ------------------------'
 
INSERT INTO #procs
SELECT DISTINCT o.name
	 , m.object_id
     , m.definition
     , m.uses_ansi_nulls
     , m.uses_quoted_identifier
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON m.object_id = o.object_id
WHERE o.type = 'P'
	AND o.name like @measure_name+'%'
	AND (SELECT COUNT(*) FROM #procs p WHERE p.name = o.name) = 0

-- get procs when the pattern was not followed
 
 INSERT INTO #procs (name)
 SELECT DISTINCT NumeratorProcName
 FROM HQM_Measure.dbo.Measure
 WHERE MeasureName = @measure_name
	AND NumeratorProcName IS NOT NULL
	AND LEN(NumeratorProcName) > 0
 
 UNION  
 
 SELECT DISTINCT DeonimatorProcName
 FROM HQM_Measure.dbo.Measure
 WHERE MeasureName = @measure_name
	AND DeonimatorProcName IS NOT NULL
	AND LEN(DeonimatorProcName) > 0
 
 UNION  
 
 SELECT DISTINCT ExclusionProcName
 FROM HQM_Measure.dbo.Measure
 WHERE MeasureName = @measure_name
	AND ExclusionProcName IS NOT NULL
	AND LEN(ExclusionProcName) > 0
 
 UNION  
 
 SELECT DISTINCT InitPopulationProcName
 FROM HQM_Measure.dbo.Measure
 WHERE MeasureName = @measure_name
	AND InitPopulationProcName IS NOT NULL
	AND LEN(InitPopulationProcName) > 0

 SET @proclist = CURSOR FOR
 SELECT 'StoredProcedures\Programs\' + @folder_name + '\Measures\dbo.'+name+'.sql'
 FROM #procs
 ORDER BY name

 OPEN @proclist
 FETCH NEXT
 FROM @proclist INTO @name
 
 WHILE @@FETCH_STATUS = 0
 BEGIN
	PRINT @name
 FETCH NEXT
 FROM @proclist INTO @name
 END
 CLOSE @proclist
 DEALLOCATE @proclist

DROP TABLE #procs

GO


 --select * FROM #procs
 
   ------------------------------------------------------------------------------------------------------  CREATE PROCEDURE dbo.EvaluateAll_CMS137_Strat2_Num1   (@start_date datetime,@end_date datetime,@location_scoping bit=0)   AS   BEGIN   SET NOCOUNT ON;   DECLARE @measure_name varchar(50);   SET @measure_name = 'CMS137_Strat2_Num1';   DECLARE @measure_id int;   SELECT @measure_id=MeasureID FROM Measure WHERE MeasureName=@measure_name;      EXECUTE  EvaluateDenominator_CMS137_Strat2_Num1 @start_date, @end_date, @location_scoping     declare @PracticeLocationExcludeCount int;   select @PracticeLocationExcludeCount = COUNT(*) from PracticeLocation where HqmParticipationInd = 0;   IF @PracticeLocationExcludeCount > 0      exec PracticeLocationExclude   EXECUTE  EvaluateNumerator_CMS137_Strat2_Num1 @start_date, @end_date, @location_scoping   EXECUTE  EvaluateAutoExclusion_CMS137_Strat2_Num1 @start_date, @end_date, @location_scoping    END     
