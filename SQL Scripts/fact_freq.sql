/****** Object:  Table [dbo].[fact_freq]    Script Date: 31/01/2017 2:28:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[fact_freq](
	[Code] [int] NULL,
	[Frequency] [int] NULL,
	[DateTime] [datetime] NOT NULL
)

GO

ALTER TABLE [dbo].[fact_freq] ADD  CONSTRAINT [DF_fact_freq_DateTime]  DEFAULT (getdate()) FOR [DateTime]
GO


