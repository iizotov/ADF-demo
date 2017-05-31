/****** Object:  Table [dbo].[stg_log]    Script Date: 31/01/2017 2:29:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[stg_log](
	[IpAddress] [varchar](max) NULL,
	[DateStr] [varchar](max) NULL,
	[Request] [varchar](max) NULL,
	[Code] [int] NULL,
	[ADFSliceIdentifier] [binary](32) NULL
)

GO
