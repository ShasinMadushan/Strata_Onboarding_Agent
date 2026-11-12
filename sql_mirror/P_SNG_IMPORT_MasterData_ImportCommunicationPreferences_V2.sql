
CREATE PROCEDURE [dbo].[P_SNG_IMPORT_MasterData_ImportCommunicationPreferences_V2]

@ManagingCompanyCode   VARCHAR(30),
@PropertyID INT

AS  

BEGIN
SET NOCOUNT ON 
SET XACT_ABORT ON  

DECLARE @EXTERNAL_TRANCOUNT INT;
    SET @EXTERNAL_TRANCOUNT = @@TRANCOUNT;

    BEGIN TRY

    IF @EXTERNAL_TRANCOUNT = 0 -- There is no existing transaction. If there's one no need to start another.
    BEGIN TRANSACTION;
    

    --select SM_Agent_ContactType  from [dbo].[T_SNG_IMPORT_MasterData]

--[dbo].[T_SNG_Import_LotDetails] 

-- T_SNG_IMPORT_MasterData_CommunicationPreferences

 declare @PlanNumber VARCHAR(50);

select @PlanNumber = PlanNumber
FROM [dbo].F_SNG_Properties_L3_CORE(69)
WHERE PropertyID = @PropertyID AND ManagingCompanyCode = @ManagingCompanyCode;

IF(@PlanNumber IS NULL)
RETURN;

--SELECT * FROM [dbo].[T_SNG_IMPORT_Com_Pref]

INSERT INTO [dbo].[T_SNG_IMPORT_Com_Pref] (PropertyID, PlanNumber, LotID, OwnerID, Lot_No, FeeNotice_Owner, Correspondence_Owner, Notice_Owner, FeeNotice_Agent, Correspondence_Agent, Notice_Agent, FeeNotice_Other1, Correspondence_Other1, Notice_Other1, FeeNotice_Other2, Correspondence_Other2, Notice_Other2, FeeNotice_Other3, Correspondence_Other3, Notice_Other3)
SELECT @PropertyID, @PlanNumber, LotID, OwnerID, Lot_No, FeeNotice_Owner, Correspondence_Owner, Notice_Owner, FeeNotice_Agent, Correspondence_Agent, Notice_Agent, FeeNotice_Other1, Correspondence_Other1, Notice_Other1, FeeNotice_Other2, Correspondence_Other2, Notice_Other2, FeeNotice_Other3, Correspondence_Other3, Notice_Other3
FROM [dbo].[syn_ERP_T_SNG_IMPORT_Com_Pref] COM 
    INNER JOIN T_SNG_LOTS L ON L.Lot_Number = COM.Lot_No AND L.PROPERTYID =  @PropertyID

 IF OBJECT_ID('tempdb.dbo.#Owners') IS NOT NULL
                DROP TABLE #Owners;

 SELECT PropertyID, PlanNumber, LotID, OwnerID, Lot_No, FeeNotice_Owner, Correspondence_Owner, Notice_Owner, FeeNotice_Agent, Correspondence_Agent, Notice_Agent, FeeNotice_Other1, Correspondence_Other1, Notice_Other1, FeeNotice_Other2, Correspondence_Other2, Notice_Other2, FeeNotice_Other3, Correspondence_Other3, Notice_Other3
 INTO #Owners
 FROM [dbo].[T_SNG_IMPORT_Com_Pref]
 where PROPERTYID =  @PropertyID;
 
      
INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L
INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_Owner IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)




 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L
INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_Owner IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_Owner IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)

---end email owner main


--agent email 
INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_Agent IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_Agent IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_Agent IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)

--END AGENT EMAIL

--OTHER 1 EMAIL

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER1 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER1 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER1 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)

--END EMAIL OTHER 1

--START EMAIL OTHER 2

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER2 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER2 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER2 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)

--END OTHER 2 EMAIL

--START OTHER3 EMAIL

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER3 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER3 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'EMAIL'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER3 IN( 'E' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'EMAIL'
)
--post

-----------------------------------------------------
-------------------------------------------------------


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_Owner IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_Owner IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OWNER-MAIN'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_Owner IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)

---end email owner main


--agent email 
INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_Agent IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_Agent IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'AGENT'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_Agent IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)

--END AGENT EMAIL

--OTHER 1 EMAIL

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER1 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER1 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER1'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER1 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)

--END EMAIL OTHER 1

--START EMAIL OTHER 2

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER2 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER2 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER2'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER2 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)

--END OTHER 2 EMAIL

--START OTHER3 EMAIL

INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'LEVY') ComType
where FeeNotice_OTHER3 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)



 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'CORRESPONDENCE') ComType
where Correspondence_OTHER3 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)


 INSERT INTO [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences]
   ([OwnerID]
   ,[ContactTypeCode]
   ,[ComGroupCode]
   ,[ComPreference]
   ,[LastModified]
   ,[LastModifiedUserID])
select l.[OwnerID]
   ,ct.[ContactTypeCode]
   ,ComType.[ComGroupCode]
   ,[ComPreference] = 'POST'
   ,[LastModified] = GETDATE()
   ,[LastModifiedUserID] = 69
from #Owners L

INNER JOIN T_SNG_STRATA_OWNERCONTACTS CT ON CT.OWNERID = L.OWNERID AND CT.ContactTypeCode = 'OTHER3'
CROSS JOIN (select ComGroupCode ,DisplayGroup from dbo.T_SNG_STRATA_CommunicationGroups WHERE ComGroupKey = 'OWNER' AND DisplayGroup = 'NOTICE') ComType
where Notice_OTHER3 IN( 'P' ,'EP')
and NOT EXISTS (
SELECT 1 FROM [dbo].[T_SNG_STRATA_REL_OwnerCommunicationGroupPreferences] Pref 
WHERE Pref.[OwnerID] = L.OWNERID
AND Pref.[ContactTypeCode] = CT.ContactTypeCode
AND Pref.[ComGroupCode] = ComType.[ComGroupCode]
AND Pref.[ComPreference] = 'POST'
)




--COMMIT AT THE END OF THE WORK
    IF (@EXTERNAL_TRANCOUNT = 0 AND  @@TRANCOUNT > 0) -- We are not committing external transactions. There is a local transaction to commit
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        --ROLLBACK AT THE VERY BEGINING OF THE CATCH - DON'T DO ANY WORK BEFORE THIS STATEMENT

DECLARE  @ErrorMessage     VARCHAR(1000),
         @ErrorNumber      INT,
 @ErrorSeverity    INT,
 @ErrorState       INT,
 @ErrorProcedure   VARCHAR(300),
 @ErrorLine        INT, 
 @PortalName       VARCHAR(200);

        SELECT   @ErrorMessage   = OBJECT_NAME(@@PROCID) + '|' + ERROR_MESSAGE(),
         @ErrorNumber    = ERROR_NUMBER(),
 @ErrorSeverity  = ERROR_SEVERITY(),
                 @ErrorState     = ERROR_STATE(),
 @ErrorProcedure = ERROR_PROCEDURE(),
 @ErrorLine      = ERROR_LINE(),
 @PortalName     = OBJECT_NAME(@@PROCID);

        if (@EXTERNAL_TRANCOUNT = 0 AND  @@TRANCOUNT > 0) -- We are not rolling back external transactions. There is a local transaction to rollback
        BEGIN
            ROLLBACK;

--REPORT THE ERROR - OR THROW A NEW ERROR SHOULD BE DONE AFTER THE ROLLBACK 
EXEC [dbo].[P_SNG_STRATA_AddSystemSQLErrors]
            @ErrorMessage   = @ErrorMessage,
            @ErrorNumber    = @ErrorNumber,
            @ErrorSeverity  = @ErrorSeverity,
            @ErrorState     = @ErrorState,
            @ErrorProcedure = @ErrorProcedure,
            @ErrorLine      = @ErrorLine,
            @PortalName     = @PortalName;

        END
       

        RAISERROR (@ErrorMessage, -- Error Message text.  --It's best to throw the actual message or custom message
                        16, -- Severity. 
                        2 -- State. 
                        );    

    END CATCH;

END

