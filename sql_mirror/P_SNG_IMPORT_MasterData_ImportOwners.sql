
CREATE PROCEDURE [dbo].[P_SNG_IMPORT_MasterData_ImportOwners]
    
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


  declare @PlanNumber VARCHAR(50);

 select @PlanNumber = PlanNumber
 FROM F_SNG_Properties_L3_CORE(69)
 WHERE PropertyID = @PropertyID AND ManagingCompanyCode = @ManagingCompanyCode;

 IF(@PlanNumber IS NULL)
 RETURN;
 
        update L
   set l.SNG_OwnerID = ll.OwnerID
   from [dbo].[T_SNG_IMPORT_MasterData] l
   inner join [dbo].F_SNG_Properties_L3_CORE(69) p on p.PropertyID = l.SNG_PropertyID 
   inner join [dbo].T_SNG_Lots ll on ll.LotID = l.SNG_LotID and p.PropertyID = ll.PropertyID
   where p.PlanNumber = @PlanNumber and p.ManagingCompanyCode = @ManagingCompanyCode AND L.SNG_LotID IS NULL;
   


   DECLARE @ID INT;




DECLARE db_cursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR 
SELECT ID
FROM [dbo].[T_SNG_IMPORT_MasterData] 
WHERE SNG_LotID IS NOT NULL and SNG_OwnerID IS NULL 
AND trim(PlanNumber) = @PlanNumber
order by id
 

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @ID

WHILE @@FETCH_STATUS = 0  
BEGIN  


DECLARE @SNG_LotID INT = NULL;
DECLARE @SM_OwnerContactID INT = NULL;
DECLARE @SNG_OwnerID INT = NULL;
DECLARE @UserID int = 69;


--CONTACT RELAED VARIABLES-------
 DECLARE @StreetNo VARCHAR(20)= NULL,   
   @PoBox VARCHAR(20)= NULL,
   @Line1 VARCHAR(500)= NULL,
   @Line2 VARCHAR(500)= NULL,
   @Line3 VARCHAR(500)= NULL,
   @Line4 VARCHAR(500)= NULL,
   @Line5 VARCHAR(500)= NULL,
   @AusType VARCHAR(10) = 'AUS',
   @PoboxType VARCHAR(10)= NULL,
   @InterAdds VARCHAR(10)= NULL,
   @PostCodePo VARCHAR(8)= NULL,
   @SuburbPo VARCHAR(100)= NULL,
   @StateCodePo VARCHAR(3)= NULL,
   @SNG_UserID INT = 69,
   @CompanyCode VARCHAR(20)= @ManagingCompanyCode,
   @Country VARCHAR(200),
   @AddressIdOut INT = NULL,
   @ReturnMessage VARCHAR(MAX)= NULL 

 DECLARE @FirstName VARCHAR(200)= NULL,
   @MiddleName VARCHAR(200)= NULL,
   @LastName VARCHAR(200)= NULL,
   @ContactName VARCHAR(300)= NULL,
   @Mobile VARCHAR(200)= NULL,
   @Mobile_Notes VARCHAR(100)= NULL,
   @Mobile2 VARCHAR(200)= NULL,
   @Mobile2_Notes VARCHAR(100)= NULL,
   @LandLine1 VARCHAR(200)= NULL,
   @LandLine1_Notes NVARCHAR(200)= NULL,
   @LandLine2 VARCHAR(200)= NULL,
   @LandLine2_Notes VARCHAR(100)= NULL,
   @Email1 VARCHAR(300)= NULL,
   @Email2 VARCHAR(200)= NULL,
   @Email3 VARCHAR(200)= NULL,
   @Fax VARCHAR(200)= NULL,
   @Title VARCHAR(10)= NULL,
   @BusinessName  VARCHAR(200)= NULL,
   @OtherNames VARCHAR(200) = NULL,
   @ContactId INT= NULL,
   @ContactIdOut INT = NULL,
   @Response VARCHAR(MAX) = NULL
--END CONTAC REALTED VARIABLES----

--CONTACT to CONTACT TYPE Mapping variables
 DECLARE
     @Mapping_ComType VARCHAR(MAX),
     @Mapping_ContactId INT,
     @Mapping_ContactTypeCode VARCHAR(30), 
     @Mapping_OwnerID INT,
     @SM_ContactID INT,
     @Mapping_ResponseMSG varchar(max)
--END CONTACT to CONTACT TYPE Mapping variables


--select * from T_SNG_IMPORT_MasterData

--select * from [T_SNG_IMPORT_MasterData]

--UPDATE N
--SET 
--SNG_LotID = O.SNG_LotID, SNG_OwnerID = O.SNG_OwnerID, SNG_OwnerContactID = O.SNG_OwnerContactID, SNG_LevyContactID = O.SNG_LevyContactID, SNG_NoticeContactID = O.SNG_NoticeContactID
----select * 
--from dbo.T_SNG_IMPORT_MasterData N
--INNER JOIN [T_SNG_IMPORT_MasterData] O ON N.SM_LotID = O.SM_LotID
--WHERE O.SNG_LotID IS NOT NULL
DECLARE 
  @Lot_Number varchar(20),
  
  @OwnerOccupied  varchar(10),
  @LotType VARCHAR(10) = 1,
  @Lot_Notes VARCHAR(MAX) = NULL,
  @ReturnAddressID INT

SELECT 
@SNG_LotID = SNG_LotID, @SM_OwnerContactID = SM_OwnerContactID, @SNG_OwnerID = SNG_OwnerID,
 @Lot_Number = T.SM_Lot_Number,
 @OwnerOccupied = CASE WHEN T.SM_Lot_OwnerOccupied = '1' THEN 1 WHEN T.SM_Lot_OwnerOccupied = '0' THEN 0  END,--L.bOwnerOccupied,
 @PlanNumber = T.PlanNumber    --OC.sPlanNumber
 , @ReturnAddressID = SNG_LotAddressID
FROM [dbo].[T_SNG_IMPORT_MasterData] T
WHERE [ID] = @ID;

PRINT @SNG_LotID



 SELECT @PropertyID = PropertyID
 FROM T_SNG_Properties
 WHERE RTRIM(LTRIM(PlanNumber)) = RTRIM(LTRIM(@PlanNumber)) --LIKE '%'+RTRIM(LTRIM(@PlanNumber))+'%'
 select @PropertyID

 UPDATE dbo.T_SNG_IMPORT_MasterData
   SET SNG_PropertyID = @PropertyID
 WHERE ID = @ID



   IF @OwnerOccupied = '1'
   BEGIN
    Update dbo.T_SNG_Lots
    SET IsOwnerOccupied = 1
    WHERE LotID = @SNG_LotID
   END

/**** Create Owner ID*****/
IF (@SNG_OwnerID IS NULL)
BEGIN
 DECLARE @CompanyID int,
   @LotID int,
   @IsActiveLot varchar(10),
   @OwnerID int,
   @NameOnTitle varchar(max), 
   @OwnershipStartDate datetime,
   @PurchaseDate datetime,
   @Positions varchar(max) = NULL,
   @PositionStartDate datetime = NULL,
   @IsCommitteeMemeber varchar(10) = NULL,
   @NameOnTitleChanged int = 0,
   @OD_Interest_Charging_Enabled VARCHAR(6) = NULL, 
   @OD_WriteOff_Unpaid_Interest VARCHAR(6) = NULL, 
   @OD_WriteOff_Unpaid_Interest_Limit VARCHAR(6) = NULL, 
   @OD_Write_off_interest_when_paid_in_full VARCHAR(6) = NULL, 
   @OD_Write_off_interest_when_paid_in_full_Limit VARCHAR(6) = NULL,
   @lotused VARCHAR(10) = 'R'
   --@UserID int = 1518,
   --@PropertyID INT, 
   --@PlanNumber VARCHAR(100),
   --@LotNumber VARCHAR(10),

 DECLARE @ReturnOwnerID INT;

  --SET @PlanNumber = @PlanNumber
  --SET @LotNumber = @LotNumber

   SELECT @NameOnTitle = SM_Owner_NameOnTitle, @OwnershipStartDate =SM_Owner_OwnershipStartDate , @PurchaseDate = SM_Owner_PurchaseDate, @Positions = SM_ExecutivePosition --case when SM_ExecutivePosition = 'Member' then 'Member' ELSE SM_ExecutivePosition END--, @PlanNumber = OwnersCorporation, @LotNumber = LotNumber 
   ,@PositionStartDate = [SM_ExecutivePositionStartDate]
   FROM  
   (
    select T.SM_Owner_NameOnTitle,  T.SM_Owner_OwnershipStartDate, T.SM_Owner_PurchaseDate, T.SM_ExecutivePosition, T.SM_ExecutivePositionStartDate--, O.sOwnerType, O.sNameOnTitle, O.dDateOfEntry, O.dPurchase,  O.sLevyIssue, O.sNoticesIssue, O.sNoticeCorrespondenceIssue, O.lOwnerContactID, O.lLevyContactID,O.lNoticeContactID
   --,Ct_Owner.*,L.*--
   --,Ct_Levy.*
   --,Ct_Notice.*
    FROM [dbo].[T_SNG_IMPORT_MasterData] T
         WHERE T.ID = @ID
   )A

  SELECT @PropertyID = PropertyID 
  FROM T_SNG_Properties 
  WHERE PlanNumber = RTRIM(LTRIM(@PlanNumber))    --LIKE '%'+RTRIM(LTRIM(@PlanNumber))+'%'

  SELECT @SNG_LotID = SNG_LotID
  FROM dbo.T_SNG_IMPORT_MasterData
  WHERE ID = @ID;

  SELECT @LotID = LotID, @IsActiveLot = IIF(IsActiveLot = 1, 'on', 'off') 
  FROM T_SNG_Lots L
  WHERE  L.LotID = @SNG_LotID;

  

  IF @PropertyID IS NULL
  BEGIN
   print 'Property ID is NULL'
  
  END

 
 
 

 EXEC [dbo].[P_SNG_PROPERTY_AddUpdateOwners_V2] 
  @ManagingCompanyCode,
  @CompanyID,
  @LotID,
  @IsActiveLot,
  @OwnerID,
  @NameOnTitle, 
  @OwnershipStartDate,
  @PurchaseDate,
  @Positions,
  @PositionStartDate,
  @IsCommitteeMemeber,
  @NameOnTitleChanged,
  @UserID,
  @ReturnAddressID,
  @OwnerOccupied,
  @ReturnOwnerId OUTPUT,
  @OD_Interest_Charging_Enabled, 
  @OD_WriteOff_Unpaid_Interest, 
  @OD_WriteOff_Unpaid_Interest_Limit, 
  @OD_Write_off_interest_when_paid_in_full, 
  @OD_Write_off_interest_when_paid_in_full_Limit,
  @Lot_Notes,
  @lotType,
  @lotused

 

 

 DELETE FROM T_SNG_STRATA_Committee_Members
 WHERE OwnerID = @ReturnOwnerId 

 IF ISNULL(@Positions,'') <> ''
 BEGIN
  --print 'z'
  INSERT INTO T_SNG_STRATA_Committee_Members (OwnerID, CommitteePositionID, PositionStartDate)
  SELECT @ReturnOwnerId, CP.CommitteePositionID, @PositionStartDate
  FROM (SELECT Item FROM [dbo].[F_SNG_UTILS_SplitString](@Positions, ','))A
  INNER JOIN dbo.T_SNG_STRATA_Committee_Positions CP ON A.Item = CP.PositionTitle
  WHERE ISNULL(A.Item,'')<>'';
 END


 UPDATE dbo.T_SNG_IMPORT_MasterData
 SET SNG_OwnerID = @ReturnOwnerId
 WHERE ID = @ID
END -- END Create Owner ID


----------------------------// Insert Owner Contact Detail //----------------------------------------------

DECLARE @SNG_OwnerContactID INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SNG_OwnerContactID = SNG_OwnerContactID 
FROM dbo.T_SNG_IMPORT_MasterData
WHERE SNG_OwnerContactID IS NOT NULL
AND SM_OwnerContactID = @SM_OwnerContactID


IF (@SNG_OwnerContactID IS NULL)
BEGIN
 
 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_OwnerContactID,
  @ContactType = 'OWNER',
  @OUT_SNG_ContactID = @SNG_OwnerContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_OwnerContactID = @SNG_OwnerContactID
  WHERE ID = @ID 

END

BEGIN
    UPDATE dbo.T_SNG_IMPORT_MasterData
    SET SNG_OwnerContactID = @SNG_OwnerContactID
    WHERE ID = @ID 
END

BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_OwnerContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID,
   @SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'OWNER-MAIN'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END



------------------------------------------------------------------------------------------------------------
----------------------------// Insert Committee Contact Detail //----------------------------------------------

DECLARE @SNG_CommitteeContactID INT = NULL;
DECLARE @SM_CommitteeContactID INT = NULL;
declare @SM_CommitteeContactType VARCHAR(1) = NULL
DECLARE @SM_Is_CommitteeContact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_CommitteeContact = T.SM_Is_CommitteeContact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID



IF (@SM_Is_CommitteeContact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_v6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_CommitteeContactID,
  @ContactType = 'COMMITTEE',
  @OUT_SNG_ContactID = @SNG_CommitteeContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_CommitteeContactID = @SNG_CommitteeContactID
  WHERE ID = @ID 

END

IF @SNG_CommitteeContactID IS NOT NULL
BEGIN /* Creating CONTACT to Committee mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_CommitteeContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'COMMITTEE'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

----------------------------/////////////////////////////////----------------------------------------------




------------------------------------------------------------------------------------------------------------
----------------------------// Insert Agent Contact Detail //----------------------------------------------

DECLARE @SNG_AgentContactID INT = NULL;
DECLARE @SM_AgentContactID INT = NULL;
declare @SM_AgentContactType VARCHAR(1) = NULL
DECLARE @SM_Is_AgentContact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_AgentContact = T.SM_Is_AgentContact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID


IF (@SM_Is_AgentContact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_AgentContactID,
  @ContactType = 'AGENT',
  @OUT_SNG_ContactID = @SNG_AgentContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_AgentContactID = @SNG_AgentContactID
  WHERE ID = @ID 

END


IF @SNG_AgentContactID IS NOT NULL
BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_AgentContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'AGENT'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

----------------------------/////////////////////////////////----------------------------------------------



------------------------------------------------------------------------------------------------------------
----------------------------// Insert Tenant Contact Detail //----------------------------------------------

DECLARE @SNG_TenantContactID INT = NULL;
DECLARE @SM_TenantContactID INT = NULL;
declare @SM_TenantContactType VARCHAR(1) = NULL
DECLARE @SM_Is_TenantContact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_TenantContact = T.SM_Is_TenantContact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID


IF (@SM_Is_TenantContact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_TenantContactID,
  @ContactType = 'TENANT',
  @OUT_SNG_ContactID = @SNG_TenantContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_TenantContactID = @SNG_TenantContactID
  WHERE ID = @ID 

END

IF @SNG_TenantContactID IS NOT NULL
BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_TenantContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'TENANT'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

----------------------------/////////////////////////////////----------------------------------------------


------------------------------------------------------------------------------------------------------------
----------------------------// Insert Other1 Contact Detail //----------------------------------------------

DECLARE @SNG_Other1ContactID INT = NULL;
DECLARE @SM_Other1ContactID INT = NULL;
declare @SM_Other1ContactType VARCHAR(1) = NULL
DECLARE @SM_Is_Other1Contact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_Other1Contact = T.SM_Is_Other1Contact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID



IF (@SM_Is_Other1Contact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_Other1ContactID,
  @ContactType = 'OTHER1',
  @OUT_SNG_ContactID = @SNG_Other1ContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_Other1ContactID = @SNG_Other1ContactID
  WHERE ID = @ID 

END

IF @SNG_Other1ContactID IS NOT NULL
BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_Other1ContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'OTHER1'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

----------------------------/////////////////////////////////----------------------------------------------

------------------------------------------------------------------------------------------------------------
----------------------------// Insert Other2 Contact Detail //----------------------------------------------

DECLARE @SNG_Other2ContactID INT = NULL;
DECLARE @SM_Other2ContactID INT = NULL;
declare @SM_Other2ContactType VARCHAR(1) = NULL
DECLARE @SM_Is_Other2Contact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_Other2Contact = T.SM_Is_Other2Contact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID


IF (@SM_Is_Other2Contact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_Other2ContactID,
  @ContactType = 'OTHER2',
  @OUT_SNG_ContactID = @SNG_Other2ContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_Other2ContactID = @SNG_Other2ContactID
  WHERE ID = @ID 

END


IF @SNG_Other2ContactID IS NOT NULL
BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_Other2ContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'OTHER2'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

  ------------------------------------------------------------------------------------------------------------
----------------------------// Insert Other3 Contact Detail //----------------------------------------------

DECLARE @SNG_Other3ContactID INT = NULL;
DECLARE @SM_Other3ContactID INT = NULL;
declare @SM_Other3ContactType VARCHAR(1) = NULL
DECLARE @SM_Is_Other3Contact INT = NULL;
--Look for the same Owner in the system. If found use that owner otherwise craete a new owner
SELECT @SM_Is_Other3Contact = T.SM_Is_Other3Contact 
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID



IF (@SM_Is_Other3Contact = 1)
BEGIN

 --EXEC dbo.p_SNG_IMPORT_Create_New_Contact
 EXEC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
  @ID = @ID,
  @UserID = @UserID,
  @ManagingCompanyCode = @ManagingCompanyCode,
  @SM_ContactID = @SM_Other3ContactID,
  @ContactType = 'OTHER3',
  @OUT_SNG_ContactID = @SNG_Other3ContactID OUTPUT

  UPDATE dbo.T_SNG_IMPORT_MasterData
  SET SNG_Other3ContactID = @SNG_Other3ContactID
  WHERE ID = @ID 

END

IF @SNG_Other3ContactID IS NOT NULL
BEGIN /* Creating CONTACT to AGENT mapping */

  SELECT
       @Mapping_ComType = NULL,
       @Mapping_ContactId = NULL,
       @Mapping_ContactTypeCode = NULL, 
       @Mapping_OwnerID = NULL,
       @SM_ContactID = NULL,
       @Mapping_ResponseMSG = NULL;

  --DECLARE @SM_ContactID INT = NULL;

  SELECT  
   @Mapping_ContactId = @SNG_Other3ContactID, --CASE @ContactType WHEN 'OWNER' THEN SNG_OwnerContactID WHEN 'LEVY' THEN SNG_LevyContactID WHEN 'NOTICE' THEN SNG_NoticeContactID END, --SNG_LevyContactID,
   @Mapping_OwnerID = T.SNG_OwnerID
   --,@SM_ContactID = T.SM_OwnerContactID
   FROM [dbo].[T_SNG_IMPORT_MasterData] T WHERE ID = @ID

  select @Mapping_ContactTypeCode = 'OTHER3'


  

  EXEC dbo.P_SNG_PROPERTY_ComTypeInsertConfirmation
       @ComType = NULL,
       @ContactId = @Mapping_ContactId,
       @ContactTypeCode = @Mapping_ContactTypeCode, 
       @OwnerID = @Mapping_OwnerID,
       @UserID = 69,
       @SupplierId = NULL,
       @CustomerId = NULL,
       @ResponseMSG = @Mapping_ResponseMSG output

  
  END

----------------------------/////////////////////////////////----------------------------------------------








UPDATE T
set SNG_LevyContactID =  CASE SM_LevyContactShare WHEN 'Owner' THEN T.SNG_OwnerContactID 
             WHEN 'AGENT' THEN T.SNG_AgentContactID 
             WHEN 'TENANT' THEN T.SNG_TenantContactID
             WHEN 'OTHER1' THEN T.SNG_Other1ContactID
             WHEN 'OTHER2' THEN T.SNG_Other2ContactID 
             WHEN 'OTHER3' THEN T.SNG_Other3ContactID END
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID



UPDATE T
set SNG_NoticeContactID =  CASE SM_NoticeContactShare WHEN 'Owner' THEN T.SNG_OwnerContactID 
             WHEN 'AGENT' THEN T.SNG_AgentContactID 
             WHEN 'TENANT' THEN T.SNG_TenantContactID
             WHEN 'OTHER1' THEN T.SNG_Other1ContactID
             WHEN 'OTHER2' THEN T.SNG_Other2ContactID  
             WHEN 'OTHER3' THEN T.SNG_Other3ContactID END
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID

SELECT 'AFTER', ID, SNG_NoticeContactID
FROM T_SNG_IMPORT_MasterData WHERE  ID = @ID

UPDATE T
set SNG_CorrespondenceContactID =  CASE SM_CorrespondenceContactShare WHEN 'Owner' THEN T.SNG_OwnerContactID 
             WHEN 'AGENT' THEN T.SNG_AgentContactID 
             WHEN 'TENANT' THEN T.SNG_TenantContactID
             WHEN 'OTHER1' THEN T.SNG_Other1ContactID
             WHEN 'OTHER2' THEN T.SNG_Other2ContactID  
             WHEN 'OTHER3' THEN T.SNG_Other3ContactID END
FROM dbo.T_SNG_IMPORT_MasterData T
WHERE ID = @ID







 

  


 FETCH NEXT FROM db_cursor INTO @ID 

END 

CLOSE db_cursor  
DEALLOCATE db_cursor 

  
  print @@TRANCOUNT
  print '-----'
  print  @EXTERNAL_TRANCOUNT

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

     print @ErrorMessage

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

