
CREATE TABLE dbo.PS732663R_Lot_Owner_Conversion_Output
(
    Lot_No                              NVARCHAR(50)  NULL,
    Unit                                NVARCHAR(50)  NULL,
    Lot_Liab                            NVARCHAR(50)  NULL,
    Lot_Ent                             NVARCHAR(50)  NULL,
    Contact_Name                        NVARCHAR(500) NULL,
    Contact_Type                        NVARCHAR(100) NULL,
    Contact_Communication_Type          NVARCHAR(100) NULL,
    Contact_Delivery_Type               NVARCHAR(100) NULL,
    Contact_Address_Building_Name       NVARCHAR(250) NULL,
    Contact_Address_Street_Number       NVARCHAR(50)  NULL,
    Contact_Address_Street_Name         NVARCHAR(250) NULL,
    Contact_Address_Street_Suburb       NVARCHAR(150) NULL,
    Contact_Address_Street_State        NVARCHAR(50)  NULL,
    Contact_Address_Street_PostCode     NVARCHAR(20)  NULL,
    Contact_Address_POBOX               NVARCHAR(150) NULL,
    Contact_Address_Country             NVARCHAR(100) NULL,
    Contact_State_Code                  NVARCHAR(50)  NULL,
    Contact_Mobile                      NVARCHAR(100) NULL,
    [Contact_Mobile 2]                  NVARCHAR(100) NULL,
    Contact_Mobile_Notes                NVARCHAR(250) NULL,
    Contact_Landline1                   NVARCHAR(100) NULL,
    Contact_Landline1_Notes             NVARCHAR(250) NULL,
    Contact_Landline2                   NVARCHAR(100) NULL,
    Contact_Landline2_Notes             NVARCHAR(250) NULL,
    Contact_Email1                      NVARCHAR(320) NULL,
    Contact_Email2                      NVARCHAR(320) NULL,
    Contact_Email3                      NVARCHAR(320) NULL,
    Payment_Reference                   NVARCHAR(100) NULL,
    [Lot address details]               NVARCHAR(500) NULL,
    Lot_Address_Building_Name           NVARCHAR(250) NULL,
    Lot_Address_Street_Number           NVARCHAR(50)  NULL,
    Lot_Address_Street_Name             NVARCHAR(250) NULL,
    Lot_Address_Street_Suburb           NVARCHAR(150) NULL,
    Lot_Address_Street_State            NVARCHAR(50)  NULL,
    Lot_Address_Street_PostCode         NVARCHAR(20)  NULL,
    Lot_Address_POBOX                   NVARCHAR(150) NULL,
    Lot_Address_Country                 NVARCHAR(100) NULL,
    IsOwnerOccupied                     NVARCHAR(50)  NULL,
    Agent_BusinessName                  NVARCHAR(250) NULL,
    ExecutivePosition                   NVARCHAR(150) NULL,
    FeeNoticeContactShare               NVARCHAR(100) NULL,
    CorrespondenceContactShare          NVARCHAR(100) NULL,
    NoticeShare                         NVARCHAR(100) NULL,
    IsCommitteeContact                  NVARCHAR(50)  NULL,
    Committee_ContactName               NVARCHAR(250) NULL,
    FeeNoticeIssue                      NVARCHAR(50)  NULL,
    NoticeIssue                         NVARCHAR(50)  NULL,
    CorrespondenceIssue                 NVARCHAR(50)  NULL,
    IsPropertyAgent                     NVARCHAR(50)  NULL,
    IsOtherContact1                     NVARCHAR(50)  NULL,
    IsOtherContact2                     NVARCHAR(50)  NULL,
    IsOtherContact3                     NVARCHAR(50)  NULL,
    IsTenant                            NVARCHAR(50)  NULL,
    IsOtherContact                      NVARCHAR(50)  NULL
);
GO


BULK INSERT dbo.PS732663R_Lot_Owner_Conversion_Output
FROM 'C:\SQLImport\PS732663R_Lot_Owner_Conversion_Output.csv'
WITH
(
    FORMAT = 'csv',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    ROWTERMINATOR = '\n',
    TABLOCK,
    KEEPNULLS
);
GO


