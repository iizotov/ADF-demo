/****** Object:  StoredProcedure [dbo].[sp_calculateFrequency]    Script Date: 31/01/2017 2:28:18 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_calculateFrequency]
AS

BEGIN
    INSERT INTO [fact_freq]
    select Code, Count(*) as Frequency, GETDATE() as DateTime from [stg_log] group by Code
END
GO


