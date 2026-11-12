

USE AboveOCM_Local_Test
GO

INSERT INTO [dbo].[T_SNG_IMPORT_MasterData_PS732663R] -- master table from Step B
(
    -- 1. Lot Details
    [PlanNumber],
    [SM_Lot_Number], 
    [SM_Lot_Unit_Number], 
    [SM_Lot_Liability], 
    [SM_Lot_VotingEntitlement],
    [SM_Lot_Address],
    [SM_Lot_BuildingName],
    [SM_Lot_StreetNumber],
    [SM_Lot_StreetName],
    [SM_Lot_Suburb],
    [SM_Lot_StateCode],
    [SM_Lot_PostCode],
    [SM_Lot_OwnerOccupied],

    -- 2. Owner Details
    [SM_Owner_ContactName], 
    [SM_Owner_NameOnTitle], 
    [SM_Owner_BuildingName], 
    [SM_Owner_StreetNumber], 
    [SM_Owner_StreetName], 
    [SM_Owner_Suburb], 
    [SM_Owner_StateCode], 
    [SM_Owner_PostCode], 
    [SM_Owner_PoBox], 
    [SM_Owner_Country], 
    [SM_Owner_Mobile1], 
    [SM_Owner_Mobile2], 
    [SM_Owner_Mobile1_Note], 
    [SM_Owner_LandLine1], 
    [SM_Owner_LandLine1_Note], 
    [SM_Owner_LandLine2], 
    [SM_Owner_LandLine2_Note], 
    [SM_Owner_Email1], 
    [SM_Owner_Email2], 
    [SM_Owner_Email3], 
    [Payment_Reference], 

    -- 3. Executive / Committee / Shares
    [SM_ExecutivePosition], 
    [SM_LevyContactShare], 
    [SM_CorrespondenceContactShare], 
    [SM_NoticeContactShare], 
    [SM_Is_CommitteeContact], 
    [SM_Committee_ContactName], 
    [SM_LevyIssue], 
    [SM_NoticeIssue], 
    [SM_CorrespondenceIssue], 

    -- 4. Flags
    [SM_Is_AgentContact], 
    [SM_Is_Other1Contact], 
    [SM_Is_Other2Contact],
    [SM_Is_TenantContact], 

    -- 5. Agent Details
    [SM_Agent_ContactName], 
    [SM_Agent_ContactType], 
    [SM_Agent_BusinessName],
    [SM_Agent_BuildingName], 
    [SM_Agent_StreetNumber], 
    [SM_Agent_StreetName], 
    [SM_Agent_Suburb], 
    [SM_Agent_StateCode], 
    [SM_Agent_PostCode], 
    [SM_Agent_PoBox], 
    [SM_Agent_Country], 
    [SM_Agent_Mobile1], 
    [SM_Agent_Mobile2], 
    [SM_Agent_Mobile1_Note], 
    [SM_Agent_LandLine1], 
    [SM_Agent_LandLine1_Note], 
    [SM_Agent_LandLine2], 
    [SM_Agent_LandLine2_Note], 
    [SM_Agent_Email1], 
    [SM_Agent_Email2], 
    [SM_Agent_Email3],

    -- 6. Other 1 Details
    [SM_Other1_ContactName],
    [SM_Other1_BuildingName],
    [SM_Other1_StreetNumber],
    [SM_Other1_StreetName],
    [SM_Other1_Suburb],
    [SM_Other1_StateCode],
    [SM_Other1_PostCode],
    [SM_Other1_PoBox],
    [SM_Other1_Country],
    [SM_Other1_Mobile1],
    [SM_Other1_Mobile2],
    [SM_Other1_Mobile1_Note],
    [SM_Other1_LandLine1],
    [SM_Other1_LandLine1_Note],
    [SM_Other1_LandLine2],
    [SM_Other1_LandLine2_Note],
    [SM_Other1_Email1],
    [SM_Other1_Email2],
    [SM_Other1_Email3],

    -- 7. Other 2 Details
    [SM_Other2_ContactName],
    [SM_Other2_BuildingName],
    [SM_Other2_StreetNumber],
    [SM_Other2_StreetName],
    [SM_Other2_Suburb],
    [SM_Other2_StateCode],
    [SM_Other2_PostCode],
    [SM_Other2_PoBox],
    [SM_Other2_Country],
    [SM_Other2_Mobile1],
    [SM_Other2_Mobile2],
    [SM_Other2_Mobile1_Note],
    [SM_Other2_LandLine1],
    [SM_Other2_LandLine1_Note],
    [SM_Other2_LandLine2],
    [SM_Other2_LandLine2_Note],
    [SM_Other2_Email1],
    [SM_Other2_Email2],
    [SM_Other2_Email3],
    [CompanyCode] 
)
SELECT 
    -- 1. Lot Details
    'PS732663R' AS [PlanNumber],
    OW.Lot_No, 
    OW.Unit, 
    OW.Lot_Liab, 
    OW.Lot_Ent, 
    OW.[Lot address details],
    OW.Lot_Address_Building_Name,
    OW.Lot_Address_Street_Number,
    OW.Lot_Address_Street_Name,
    OW.Lot_Address_Street_Suburb,
    OW.Lot_Address_Street_State,
    OW.Lot_Address_Street_PostCode,
    OW.SM_Lot_OwnerOccupied,

    -- 2. Owner Details
    OW.Owner_Contact_Name, 
    OW.Owner_Contact_Name AS [SM_Owner_NameOnTitle], 
    OW.Owner_Contact_Address_Building_Name, 
    OW.Owner_Contact_Address_Street_Number, 
    OW.Owner_Contact_Address_Street_Name, 
    OW.Owner_Contact_Address_Street_Suburb, 
    COALESCE(OW.Owner_Contact_State_Code, OW.Owner_Contact_Address_Street_State), 
    OW.Owner_Contact_Address_Street_PostCode, 
    OW.Owner_Contact_Address_POBOX, 
    OW.Owner_Contact_Address_Country, 
    OW.Owner_Contact_Mobile, 
    OW.[Owner_Contact_Mobile 2], 
    OW.Owner_Contact_Mobile_Notes, 
    OW.Owner_Contact_Landline1, 
    OW.Owner_Contact_Landline1_Notes, 
    OW.Owner_Contact_Landline2, 
    OW.Owner_Contact_Landline2_Notes, 
    OW.Owner_Contact_Email1, 
    OW.Owner_Contact_Email2, 
    OW.Owner_Contact_Email3, 
    OW.Payment_Reference, 

    -- 3. Executive / Committee / Shares
    OW.ExecutivePosition, 
    OW.FeeNoticeContactShare, 
    OW.CorrespondenceContactShare, 
    OW.NoticeShare, 
    CAST(OW.IsCommitteeContact AS bit), 
    OW.Committee_ContactName, 
    OW.FeeNoticeIssue, 
    OW.NoticeIssue, 
    OW.CorrespondenceIssue, 

    -- 4. Flags
    CAST(AG.IsPropertyAgent AS bit), 
    CAST(O1.IsOtherContact1 AS bit), 
    CAST(O2.IsOtherContact2 AS bit),
    CAST(OW.IsTenant AS bit), 

    -- 5. Agent Details
    AG.Agent_Contact_Name, 
    AG.Agent_Contact_Type, 
    AG.Agent_BusinessName,
    AG.Agent_Contact_Address_Building_Name, 
    AG.Agent_Contact_Address_Street_Number, 
    AG.Agent_Contact_Address_Street_Name, 
    AG.Agent_Contact_Address_Street_Suburb, 
    COALESCE(AG.Agent_Contact_State_Code, AG.Agent_Contact_Address_Street_State), 
    AG.Agent_Contact_Address_Street_PostCode, 
    AG.Agent_Contact_Address_POBOX, 
    AG.Agent_Contact_Address_Country, 
    AG.Agent_Contact_Mobile, 
    AG.[Agent_Contact_Mobile 2], 
    AG.Agent_Contact_Mobile_Notes, 
    AG.Agent_Contact_Landline1, 
    AG.Agent_Contact_Landline1_Notes, 
    AG.Agent_Contact_Landline2, 
    AG.Agent_Contact_Landline2_Notes, 
    AG.Agent_Contact_Email1, 
    AG.Agent_Contact_Email2, 
    AG.Agent_Contact_Email3,

    -- 6. Other 1 Details
    O1.O1_Contact_Name,
    O1.O1_Contact_Address_Building_Name,
    O1.O1_Contact_Address_Street_Number,
    O1.O1_Contact_Address_Street_Name,
    O1.O1_Contact_Address_Street_Suburb,
    COALESCE(NULLIF(O1.O1_Contact_State_Code, ''), NULLIF(O1.O1_Contact_Address_Street_State, '')),
    O1.O1_Contact_Address_Street_PostCode,
    O1.O1_Contact_Address_POBOX,
    O1.O1_Contact_Address_Country,
    O1.O1_Contact_Mobile,
    O1.[O1_Contact_Mobile 2],
    O1.O1_Contact_Mobile_Notes,
    O1.O1_Contact_Landline1,
    O1.O1_Contact_Landline1_Notes,
    O1.O1_Contact_Landline2,
    O1.O1_Contact_Landline2_Notes,
    O1.O1_Contact_Email1,
    O1.O1_Contact_Email2,
    O1.O1_Contact_Email3,

    -- 7. Other 2 Details
    O2.O2_Contact_Name,
    O2.O2_Contact_Address_Building_Name,
    O2.O2_Contact_Address_Street_Number,
    O2.O2_Contact_Address_Street_Name,
    O2.O2_Contact_Address_Street_Suburb,
    COALESCE(NULLIF(O2.O2_Contact_State_Code, ''), NULLIF(O2.O2_Contact_Address_Street_State, '')),
    O2.O2_Contact_Address_Street_PostCode,
    O2.O2_Contact_Address_POBOX,
    O2.O2_Contact_Address_Country,
    O2.O2_Contact_Mobile,
    O2.[O2_Contact_Mobile 2],
    O2.O2_Contact_Mobile_Notes,
    O2.O2_Contact_Landline1,
    O2.O2_Contact_Landline1_Notes,
    O2.O2_Contact_Landline2,
    O2.O2_Contact_Landline2_Notes,
    O2.O2_Contact_Email1,
    O2.O2_Contact_Email2,
    O2.O2_Contact_Email3,

    -- 8. Additional Metadata
    'AboveOCM' AS [CompanyCode] -- CONFIRM with team — this matches what Thulasika used in the walkthrough, but double check

FROM (
    SELECT
         [Lot_No]
        ,[Unit]
        ,[Lot_Liab] = MAX([Lot_Liab])
        ,[Lot_Ent] = MAX([Lot_Ent])
        ,[Owner_Contact_Name] = MAX([Contact_Name])
        ,[Owner_Contact_Type] = MAX([Contact_Type])
        ,[Owner_Contact_Address_Building_Name] = MAX([Contact_Address_Building_Name])
        ,[Owner_Contact_Address_Street_Number] = MAX([Contact_Address_Street_Number])
        ,[Owner_Contact_Address_Street_Name] = MAX([Contact_Address_Street_Name])
        ,[Owner_Contact_Address_Street_Suburb] = MAX([Contact_Address_Street_Suburb])
        ,[Owner_Contact_Address_Street_State] = MAX([Contact_Address_Street_State])
        ,[Owner_Contact_Address_Street_PostCode] = MAX([Contact_Address_Street_PostCode])
        ,[Owner_Contact_Address_POBOX] = MAX([Contact_Address_POBOX])
        ,[Owner_Contact_Address_Country] = MAX([Contact_Address_Country])
        ,[Owner_Contact_State_Code] = MAX([Contact_State_Code])
        ,[Owner_Contact_Mobile] = MAX([Contact_Mobile])
        ,[Owner_Contact_Mobile 2] = MAX([Contact_Mobile 2])
        ,[Owner_Contact_Mobile_Notes] = MAX([Contact_Mobile_Notes])
        ,[Owner_Contact_Landline1] = MAX([Contact_Landline1])
        ,[Owner_Contact_Landline1_Notes] = MAX([Contact_Landline1_Notes])
        ,[Owner_Contact_Landline2] = MAX([Contact_Landline2])
        ,[Owner_Contact_Landline2_Notes] = MAX([Contact_Landline2_Notes])
        ,[Owner_Contact_Email1] = MAX([Contact_Email1])
        ,[Owner_Contact_Email2] = MAX([Contact_Email2])
        ,[Owner_Contact_Email3] = MAX([Contact_Email3])
        ,[Payment_Reference] = MAX([Payment_Reference])
        ,[Lot address details] = MAX([Lot address details])
        ,[Lot_Address_Building_Name] = MAX([Lot_Address_Building_Name])
        ,[Lot_Address_Street_Number] = MAX([Lot_Address_Street_Number])
        ,[Lot_Address_Street_Name] = MAX([Lot_Address_Street_Name])
        ,[Lot_Address_Street_Suburb] = MAX([Lot_Address_Street_Suburb])
        ,[Lot_Address_Street_State] = MAX([Lot_Address_Street_State])
        ,[Lot_Address_Street_PostCode] = MAX([Lot_Address_Street_PostCode])
        ,[Lot_Address_POBOX] = MAX([Lot_Address_POBOX])
        ,[Lot_Address_Country] = MAX([Lot_Address_Country])
        ,[SM_Lot_OwnerOccupied]=MAX([IsOwnerOccupied])
        ,[ExecutivePosition] = MAX([ExecutivePosition])
        ,[FeeNoticeContactShare] = MAX([FeeNoticeContactShare])
        ,[CorrespondenceContactShare] = MAX([CorrespondenceContactShare])
        ,[NoticeShare] = MAX([NoticeShare])
        ,[IsCommitteeContact] = MAX([IsCommitteeContact])
        ,[Committee_ContactName] = MAX([Committee_ContactName])
        ,[FeeNoticeIssue] = MAX([FeeNoticeIssue])
        ,[NoticeIssue] = MAX([NoticeIssue])
        ,[CorrespondenceIssue] = MAX([CorrespondenceIssue])
        ,[IsTenant] = MAX([IsTenant])
    FROM [dbo].[PS732663R_Lot_Owner_Conversion_Output] -- staging table from Step A
    WHERE [Contact_Type] = 'Owner'
    GROUP BY [Lot_No],[Unit]
) AS OW

LEFT JOIN (
    SELECT
         [Lot_No]
        ,[Unit]
        ,[Agent_Contact_Name] = MAX([Contact_Name])
        ,[Agent_Contact_Type] = MAX([Contact_Type])
        ,[Agent_Contact_Address_Building_Name] = MAX([Contact_Address_Building_Name])
        ,[Agent_Contact_Address_Street_Number] = MAX([Contact_Address_Street_Number])
        ,[Agent_Contact_Address_Street_Name] = MAX([Contact_Address_Street_Name])
        ,[Agent_Contact_Address_Street_Suburb] = MAX([Contact_Address_Street_Suburb])
        ,[Agent_Contact_Address_Street_State] = MAX([Contact_Address_Street_State])
        ,[Agent_Contact_Address_Street_PostCode] = MAX([Contact_Address_Street_PostCode])
        ,[Agent_Contact_Address_POBOX] = MAX([Contact_Address_POBOX])
        ,[Agent_Contact_Address_Country] = MAX([Contact_Address_Country])
        ,[Agent_Contact_State_Code] = MAX([Contact_State_Code])
        ,[Agent_Contact_Mobile] = MAX([Contact_Mobile])
        ,[Agent_Contact_Mobile 2] = MAX([Contact_Mobile 2])
        ,[Agent_Contact_Mobile_Notes] = MAX([Contact_Mobile_Notes])
        ,[Agent_Contact_Landline1] = MAX([Contact_Landline1])
        ,[Agent_Contact_Landline1_Notes] = MAX([Contact_Landline1_Notes])
        ,[Agent_Contact_Landline2] = MAX([Contact_Landline2])
        ,[Agent_Contact_Landline2_Notes] = MAX([Contact_Landline2_Notes])
        ,[Agent_Contact_Email1] = MAX([Contact_Email1])
        ,[Agent_Contact_Email2] = MAX([Contact_Email2])
        ,[Agent_Contact_Email3] = MAX([Contact_Email3])
        ,[Agent_BusinessName] = MAX([Agent_BusinessName])
        ,[IsPropertyAgent] = MAX([IsPropertyAgent])
    FROM [dbo].[PS732663R_Lot_Owner_Conversion_Output] -- staging table from Step A
    WHERE [Contact_Type] = 'Agent'
    GROUP BY [Lot_No],[Unit]
) AS AG ON OW.[Lot_No] = AG.[Lot_No]

LEFT JOIN (
    SELECT
         [Lot_No]
        ,[Unit]
        ,[O1_Contact_Name] = MAX([Contact_Name])
        ,[O1_Contact_Address_Building_Name] = MAX([Contact_Address_Building_Name])
        ,[O1_Contact_Address_Street_Number] = MAX([Contact_Address_Street_Number])
        ,[O1_Contact_Address_Street_Name] = MAX([Contact_Address_Street_Name])
        ,[O1_Contact_Address_Street_Suburb] = MAX([Contact_Address_Street_Suburb])
        ,[O1_Contact_Address_Street_State] = MAX([Contact_Address_Street_State])
        ,[O1_Contact_Address_Street_PostCode] = MAX([Contact_Address_Street_PostCode])
        ,[O1_Contact_Address_POBOX] = MAX([Contact_Address_POBOX])
        ,[O1_Contact_Address_Country] = MAX([Contact_Address_Country])
        ,[O1_Contact_State_Code] = MAX([Contact_State_Code])
        ,[O1_Contact_Mobile] = MAX([Contact_Mobile])
        ,[O1_Contact_Mobile 2] = MAX([Contact_Mobile 2])
        ,[O1_Contact_Mobile_Notes] = MAX([Contact_Mobile_Notes])
        ,[O1_Contact_Landline1] = MAX([Contact_Landline1])
        ,[O1_Contact_Landline1_Notes] = MAX([Contact_Landline1_Notes])
        ,[O1_Contact_Landline2] = MAX([Contact_Landline2])
        ,[O1_Contact_Landline2_Notes] = MAX([Contact_Landline2_Notes])
        ,[O1_Contact_Email1] = MAX([Contact_Email1])
        ,[O1_Contact_Email2] = MAX([Contact_Email2])
        ,[O1_Contact_Email3] = MAX([Contact_Email3])
        ,[IsOtherContact1] = MAX([IsOtherContact1])
    FROM [dbo].[PS732663R_Lot_Owner_Conversion_Output] -- staging table from Step A
    WHERE [Contact_Type] = 'Other1'
    GROUP BY [Lot_No],[Unit]
) AS O1 ON OW.[Lot_No] = O1.[Lot_No]

LEFT JOIN (
    SELECT
         [Lot_No]
        ,[Unit]
        ,[O2_Contact_Name] = MAX([Contact_Name])
        ,[O2_Contact_Address_Building_Name] = MAX([Contact_Address_Building_Name])
        ,[O2_Contact_Address_Street_Number] = MAX([Contact_Address_Street_Number])
        ,[O2_Contact_Address_Street_Name] = MAX([Contact_Address_Street_Name])
        ,[O2_Contact_Address_Street_Suburb] = MAX([Contact_Address_Street_Suburb])
        ,[O2_Contact_Address_Street_State] = MAX([Contact_Address_Street_State])
        ,[O2_Contact_Address_Street_PostCode] = MAX([Contact_Address_Street_PostCode])
        ,[O2_Contact_Address_POBOX] = MAX([Contact_Address_POBOX])
        ,[O2_Contact_Address_Country] = MAX([Contact_Address_Country])
        ,[O2_Contact_State_Code] = MAX([Contact_State_Code])
        ,[O2_Contact_Mobile] = MAX([Contact_Mobile])
        ,[O2_Contact_Mobile 2] = MAX([Contact_Mobile 2])
        ,[O2_Contact_Mobile_Notes] = MAX([Contact_Mobile_Notes])
        ,[O2_Contact_Landline1] = MAX([Contact_Landline1])
        ,[O2_Contact_Landline1_Notes] = MAX([Contact_Landline1_Notes])
        ,[O2_Contact_Landline2] = MAX([Contact_Landline2])
        ,[O2_Contact_Landline2_Notes] = MAX([Contact_Landline2_Notes])
        ,[O2_Contact_Email1] = MAX([Contact_Email1])
        ,[O2_Contact_Email2] = MAX([Contact_Email2])
        ,[O2_Contact_Email3] = MAX([Contact_Email3])
        ,[IsOtherContact2] = MAX([IsOtherContact])
    FROM [dbo].[PS732663R_Lot_Owner_Conversion_Output] -- staging table from Step A
    WHERE [Contact_Type] = 'Other2'
    GROUP BY [Lot_No],[Unit]
) AS O2 ON OW.[Lot_No] = O2.[Lot_No];


