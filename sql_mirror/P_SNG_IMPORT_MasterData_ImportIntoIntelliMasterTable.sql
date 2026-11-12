
CREATE   PROCEDURE [dbo].[P_SNG_IMPORT_MasterData_ImportIntoIntelliMasterTable]
    
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
     

    --select SM_Agent_ContactType  from [dbo].[T_SNG_IMPORT_MasterData_NEW_Test4]

 declare @PlanNumber VARCHAR(50);

 select @PlanNumber = PlanNumber
 FROM F_SNG_Properties_L3_CORE(69)
 WHERE PropertyID = @PropertyID AND ManagingCompanyCode = @ManagingCompanyCode;

 IF(@PlanNumber IS NULL)
 RETURN;
 
 insert into [dbo].[T_SNG_IMPORT_MasterData]
(

CompanyCode
,SM_OCID
,PlanNumber
,SNG_PropertyID
,SM_LotID
,SM_OWNERID
,SM_Lot_Number
,SM_Lot_Unit_Number
,SM_Lot_Unit_NumberPrefix
,SM_Lot_Unit_NumberSuffix
,SM_OwnerContactID
,SM_AgentContactID
,SM_TenantContactID
,SM_Other1ContactID
,SM_Other2ContactID
,SM_CommitteeContactID
,SM_LevyContactID
,SM_NoticeContactID
,SM_CorrespondenceContactID
,SNG_LotID
,SNG_LotAddressID
,SNG_OwnerID
,SNG_OwnerContactID
,SNG_AgentContactID
,SNG_TenantContactID
,SNG_Other1ContactID
,SNG_Other2ContactID
,SNG_LevyContactID
,SNG_NoticeContactID
,SNG_CorrespondenceContactID
,SM_LevyIssue
,SM_NoticeIssue
,SM_CorrespondenceIssue
,SM_Lot_BuildingName
,SM_Lot_StreetNumber
,SM_Lot_StreetNumberSuffix
,SM_Lot_StreetName
,SM_Lot_Suburb
,SM_Lot_StateCode
,SM_Lot_PostCode
,SM_Lot_OwnerOccupied
,SM_Lot_Notes
,SM_Lot_Address
,SM_Lot_ExcludeDebtRecoveryNotice
,SM_Lot_UseOwnersLevyEmail
,SM_Lot_UseAgentsLevyEmail
,SM_Lot_UseTenantsLevyEmail
,SM_Lot_UseOwnersNoticeEmail
,SM_Lot_UseAgentsNoticeEmail
,SM_Lot_UseTenantsNoticeEmail
,SM_Lot_UseOwnersCorrespondenceEmail
,SM_Lot_UseAgentsCorrespondenceEmail
,SM_Lot_UseTenantsCorrespondenceEmail
,SM_Lot_PaymentPlanActive
,SM_Owner_BuildingName
,SM_Owner_StreetNumber
,SM_Owner_StreetName
,SM_Owner_Suburb
,SM_Owner_StateCode
,SM_Owner_PostCode
,SM_Owner_PoBox
,SM_Owner_Country
,SM_Owner_FirstName
,SM_Owner_ContactName
,SM_Owner_Mobile1
,SM_Owner_Mobile1_Note
,SM_Owner_Mobile2
,SM_Owner_Mobile2_Note
,SM_Owner_LandLine1
,SM_Owner_LandLine1_Note
,SM_Owner_LandLine2
,SM_Owner_LandLine2_Note
,SM_Owner_Email1
,SM_Owner_Email2
,SM_Owner_Email3
,SM_Owner_Fax
,SM_Owner_Title
,SM_Owner_BusinessName
,SM_Owner_OtherNames
,SM_Owner_CurrentOwner
,SM_Owner_IsBusinessContact
,SM_LevyCon_BuildingName
,SM_LevyCon_StreetNumber
,SM_LevyCon_StreetName
,SM_LevyCon_Suburb
,SM_LevyCon_StateCode
,SM_LevyCon_PostCode
,SM_LevyCon_PoBox
,SM_LevyCon_Country
,SM_LevyCon_FirstName
,SM_LevyCon_ContactName
,SM_LevyCon_Mobile
,SM_LevyCon_LandLine1
,SM_LevyCon_LandLine2
,SM_LevyCon_Email1
,SM_LevyCon_Email2
,SM_LevyCon_Email3
,SM_LevyCon_Fax
,SM_LevyCon_Title
,SM_LevyCon_OtherNames
,SM_LevyCon_ContactType
,SM_LevyCon_IsBusinessContact
,SM_NoticeCon_BuildingName
,SM_NoticeCon_StreetNumber
,SM_NoticeCon_StreetName
,SM_NoticeCon_Suburb
,SM_NoticeCon_StateCode
,SM_NoticeCon_PostCode
,SM_NoticeCon_PoBox
,SM_NoticeCon_Country
,SM_NoticeCon_FirstName
,SM_NoticeCon_ContactName
,SM_NoticeCon_Mobile
,SM_NoticeCon_LandLine1
,SM_NoticeCon_LandLine2
,SM_NoticeCon_Email1
,SM_NoticeCon_Email2
,SM_NoticeCon_Email3
,SM_NoticeCon_Fax
,SM_NoticeCon_Title
,SM_NoticeCon_OtherNames
,SM_NoticeCon_ContactType
,SM_NoticeCon_IsBusinessContact
,SM_CorrespondenceCon_BuildingName
,SM_CorrespondenceCon_StreetNumber
,SM_CorrespondenceCon_StreetName
,SM_CorrespondenceCon_Suburb
,SM_CorrespondenceCon_StateCode
,SM_CorrespondenceCon_PostCode
,SM_CorrespondenceCon_PoBox
,SM_CorrespondenceCon_Country
,SM_CorrespondenceCon_FirstName
,SM_CorrespondenceCon_ContactName
,SM_CorrespondenceCon_Mobile
,SM_CorrespondenceCon_LandLine1
,SM_CorrespondenceCon_LandLine2
,SM_CorrespondenceCon_Email1
,SM_CorrespondenceCon_Email2
,SM_CorrespondenceCon_Email3
,SM_CorrespondenceCon_Fax
,SM_CorrespondenceCon_Title
,SM_CorrespondenceCon_OtherNames
,SM_CorrespondenceCon_ContactType
,SM_CorrespondenceCon_IsBusinessContact
,SM_Owner_OwnershipStartDate
,SM_Owner_PurchaseDate
,SM_Owner_NameOnTitle
,SM_Owner_LastName
,SM_LevyCon_LastName
,SM_NoticeCon_LastName
,SM_CorrespondenceCon_LastName
,SM_Agent_ContactName
,SM_Agent_BusinessName
,SM_Agent_Title
,SM_Agent_OtherNames
,SM_Agent_BuildingName
,SM_Agent_StreetNumber
,SM_Agent_StreetName
,SM_Agent_Suburb
,SM_Agent_StateCode
,SM_Agent_PostCode
,SM_Agent_PoBox
,SM_Agent_Country
,SM_Agent_Mobile1
,SM_Agent_Mobile1_Note
,SM_Agent_Mobile2
,SM_Agent_Mobile2_Note
,SM_Agent_LandLine1
,SM_Agent_LandLine1_Note
,SM_Agent_LandLine2
,SM_Agent_LandLine2_Note
,SM_Agent_Email1
,SM_Agent_Email2
,SM_Agent_Email3
,SM_Agent_Fax
,SM_Agent_IsBusinessContact
,SM_Tenant_ContactName
,SM_Tenant_BusinessName
,SM_Tenant_Title
,SM_Tenant_OtherNames
,SM_Tenant_BuildingName
,SM_Tenant_StreetNumber
,SM_Tenant_StreetName
,SM_Tenant_Suburb
,SM_Tenant_StateCode
,SM_Tenant_PostCode
,SM_Tenant_PoBox
,SM_Tenant_Country
,SM_Tenant_Mobile1
,SM_Tenant_Mobile1_Note
,SM_Tenant_Mobile2
,SM_Tenant_Mobile2_Note
,SM_Tenant_LandLine1
,SM_Tenant_LandLine1_Note
,SM_Tenant_LandLine2
,SM_Tenant_LandLine2_Note
,SM_Tenant_Email1
,SM_Tenant_Email2
,SM_Tenant_Email3
,SM_Tenant_Fax
,SM_Tenant_IsBusinessContact
,SM_Other1_ContactName
,SM_Other1_BusinessName
,SM_Other1_Title
,SM_Other1_OtherNames
,SM_Other1_BuildingName
,SM_Other1_StreetNumber
,SM_Other1_StreetName
,SM_Other1_Suburb
,SM_Other1_StateCode
,SM_Other1_PostCode
,SM_Other1_PoBox
,SM_Other1_Country
,SM_Other1_Mobile1
,SM_Other1_Mobile1_Note
,SM_Other1_Mobile2
,SM_Other1_Mobile2_Note
,SM_Other1_LandLine1
,SM_Other1_LandLine1_Note
,SM_Other1_LandLine2
,SM_Other1_LandLine2_Note
,SM_Other1_Email1
,SM_Other1_Email2
,SM_Other1_Email3
,SM_Other1_Fax
,SM_Other1_IsBusinessContact
,SM_Other2_ContactName
,SM_Other2_BusinessName
,SM_Other2_Title
,SM_Other2_OtherNames
,SM_Other2_BuildingName
,SM_Other2_StreetNumber
,SM_Other2_StreetName
,SM_Other2_Suburb
,SM_Other2_StateCode
,SM_Other2_PostCode
,SM_Other2_PoBox
,SM_Other2_Country
,SM_Other2_Mobile1
,SM_Other2_Mobile1_Note
,SM_Other2_Mobile2
,SM_Other2_Mobile2_Note
,SM_Other2_LandLine1
,SM_Other2_LandLine1_Note
,SM_Other2_LandLine2
,SM_Other2_LandLine2_Note
,SM_Other2_Email1
,SM_Other2_Email2
,SM_Other2_Email3
,SM_Other2_Fax
,SM_Other2_IsBusinessContact
,SM_ExecutivePosition
,SM_LevyContactShare
,SM_NoticeContactShare
,SM_CorrespondenceContactShare
,SM_ExecutiveContactShare
,SM_Agent_ContactType
,SM_Is_AgentContact
,SM_Is_TenantContact
,SM_Is_Other1Contact
,SM_Is_Other2Contact
,SM_Lot_Liability
,SM_Lot_VotingEntitlement
,SM_ExecutivePositionStartDate
,SM_Owner_UnitNumber
,SM_Agent_UnitNo
,SM_Other2_UnitNumber
,SM_Other1_UnitNumber
,SM_Is_CommitteeContact
,SNG_CommitteeContactID
,SM_Committee_UnitNumber
,SM_Committee_ContactName
,SM_Committee_BusinessName
,SM_Committee_Title
,SM_Committee_OtherNames
,SM_Committee_BuildingName
,SM_Committee_StreetNumber
,SM_Committee_StreetName
,SM_Committee_Suburb
,SM_Committee_StateCode
,SM_Committee_PostCode
,SM_Committee_PoBox
,SM_Committee_Country
,SM_Committee_Mobile1
,SM_Committee_Mobile1_Note
,SM_Committee_Mobile2
,SM_Committee_Mobile2_Note
,SM_Committee_LandLine1
,SM_Committee_LandLine1_Note
,SM_Committee_LandLine2
,SM_Committee_LandLine2_Note
,SM_Committee_Email1
,SM_Committee_Email2
,SM_Committee_Email3
,SM_Committee_Fax
,SM_Committee_IsBusinessContact
,Batch
,Payment_Reference
,BankAccountNumber
,LotRef
,SM_RejectLevyReceipts
,LotSortingOrder
,OwnerPref
,AgentPref
,Email1_Pref
,Email2_Pref
,Email3_Pref
,SM_AgentLevyEmail
,LastReceiptDate
,SM_Other3ContactID
,SNG_Other3ContactID
,SM_Other3_ContactName
,SM_Other3_BusinessName
,SM_Other3_Title
,SM_Other3_OtherNames
,SM_Other3_BuildingName
,SM_Other3_StreetNumber
,SM_Other3_StreetName
,SM_Other3_Suburb
,SM_Other3_StateCode
,SM_Other3_PostCode
,SM_Other3_PoBox
,SM_Other3_Country
,SM_Other3_Mobile1
,SM_Other3_Mobile1_Note
,SM_Other3_Mobile2
,SM_Other3_Mobile2_Note
,SM_Other3_LandLine1
,SM_Other3_LandLine1_Note
,SM_Other3_LandLine2
,SM_Other3_LandLine2_Note
,SM_Other3_Email1
,SM_Other3_Email2
,SM_Other3_Email3
,SM_Other3_Fax
,SM_Other3_IsBusinessContact
,SM_Is_Other3Contact
,SM_Other3_UnitNumber
)

select
 M.CompanyCode
,M.SM_OCID
,PlanNumber =@PlanNumber
,SNG_PropertyID = @PropertyID
,M.SM_LotID
,M.SM_OWNERID
,M.SM_Lot_Number 
,M.SM_Lot_Unit_Number
,M.SM_Lot_Unit_NumberPrefix
,M.SM_Lot_Unit_NumberSuffix
,M.SM_OwnerContactID
,M.SM_AgentContactID
,M.SM_TenantContactID
,M.SM_Other1ContactID
,M.SM_Other2ContactID
,M.SM_CommitteeContactID
,M.SM_LevyContactID
,M.SM_NoticeContactID
,M.SM_CorrespondenceContactID
,M.SNG_LotID
,M.SNG_LotAddressID
,M.SNG_OwnerID
,M.SNG_OwnerContactID
,M.SNG_AgentContactID
,M.SNG_TenantContactID
,M.SNG_Other1ContactID
,M.SNG_Other2ContactID
,M.SNG_LevyContactID
,M.SNG_NoticeContactID
,M.SNG_CorrespondenceContactID
,M.SM_LevyIssue
,M.SM_NoticeIssue
,M.SM_CorrespondenceIssue
,M.SM_Lot_BuildingName
,M.SM_Lot_StreetNumber
,M.SM_Lot_StreetNumberSuffix
,M.SM_Lot_StreetName
,M.SM_Lot_Suburb
,M.SM_Lot_StateCode
,M.SM_Lot_PostCode
,M.SM_Lot_OwnerOccupied
,M.SM_Lot_Notes
,M.SM_Lot_Address
,M.SM_Lot_ExcludeDebtRecoveryNotice
,M.SM_Lot_UseOwnersLevyEmail
,M.SM_Lot_UseAgentsLevyEmail
,M.SM_Lot_UseTenantsLevyEmail
,M.SM_Lot_UseOwnersNoticeEmail
,M.SM_Lot_UseAgentsNoticeEmail
,M.SM_Lot_UseTenantsNoticeEmail
,M.SM_Lot_UseOwnersCorrespondenceEmail
,M.SM_Lot_UseAgentsCorrespondenceEmail
,M.SM_Lot_UseTenantsCorrespondenceEmail
,M.SM_Lot_PaymentPlanActive
,M.SM_Owner_BuildingName
,M.SM_Owner_StreetNumber
,M.SM_Owner_StreetName
,M.SM_Owner_Suburb
,M.SM_Owner_StateCode
,M.SM_Owner_PostCode
,M.SM_Owner_PoBox
,M.SM_Owner_Country
,M.SM_Owner_FirstName
,M.SM_Owner_ContactName
,M.SM_Owner_Mobile1
,M.SM_Owner_Mobile1_Note
,M.SM_Owner_Mobile2
,M.SM_Owner_Mobile2_Note
,M.SM_Owner_LandLine1
,M.SM_Owner_LandLine1_Note
,M.SM_Owner_LandLine2
,M.SM_Owner_LandLine2_Note
,M.SM_Owner_Email1
,M.SM_Owner_Email2
,M.SM_Owner_Email3
,M.SM_Owner_Fax
,M.SM_Owner_Title
,M.SM_Owner_BusinessName
,M.SM_Owner_OtherNames
,M.SM_Owner_CurrentOwner
,M.SM_Owner_IsBusinessContact
,M.SM_LevyCon_BuildingName
,M.SM_LevyCon_StreetNumber
,M.SM_LevyCon_StreetName
,M.SM_LevyCon_Suburb
,M.SM_LevyCon_StateCode
,M.SM_LevyCon_PostCode
,M.SM_LevyCon_PoBox
,M.SM_LevyCon_Country
,M.SM_LevyCon_FirstName
,M.SM_LevyCon_ContactName
,M.SM_LevyCon_Mobile
,M.SM_LevyCon_LandLine1
,M.SM_LevyCon_LandLine2
,M.SM_LevyCon_Email1
,M.SM_LevyCon_Email2
,M.SM_LevyCon_Email3
,M.SM_LevyCon_Fax
,M.SM_LevyCon_Title
,M.SM_LevyCon_OtherNames
,M.SM_LevyCon_ContactType
,M.SM_LevyCon_IsBusinessContact
,M.SM_NoticeCon_BuildingName
,M.SM_NoticeCon_StreetNumber
,M.SM_NoticeCon_StreetName
,M.SM_NoticeCon_Suburb
,M.SM_NoticeCon_StateCode
,M.SM_NoticeCon_PostCode
,M.SM_NoticeCon_PoBox
,M.SM_NoticeCon_Country
,M.SM_NoticeCon_FirstName
,M.SM_NoticeCon_ContactName
,M.SM_NoticeCon_Mobile
,M.SM_NoticeCon_LandLine1
,M.SM_NoticeCon_LandLine2
,M.SM_NoticeCon_Email1
,M.SM_NoticeCon_Email2
,M.SM_NoticeCon_Email3
,M.SM_NoticeCon_Fax
,M.SM_NoticeCon_Title
,M.SM_NoticeCon_OtherNames
,M.SM_NoticeCon_ContactType
,M.SM_NoticeCon_IsBusinessContact
,M.SM_CorrespondenceCon_BuildingName
,M.SM_CorrespondenceCon_StreetNumber
,M.SM_CorrespondenceCon_StreetName
,M.SM_CorrespondenceCon_Suburb
,M.SM_CorrespondenceCon_StateCode
,M.SM_CorrespondenceCon_PostCode
,M.SM_CorrespondenceCon_PoBox
,M.SM_CorrespondenceCon_Country
,M.SM_CorrespondenceCon_FirstName
,M.SM_CorrespondenceCon_ContactName
,M.SM_CorrespondenceCon_Mobile
,M.SM_CorrespondenceCon_LandLine1
,M.SM_CorrespondenceCon_LandLine2
,M.SM_CorrespondenceCon_Email1
,M.SM_CorrespondenceCon_Email2
,M.SM_CorrespondenceCon_Email3
,M.SM_CorrespondenceCon_Fax
,M.SM_CorrespondenceCon_Title
,M.SM_CorrespondenceCon_OtherNames
,M.SM_CorrespondenceCon_ContactType
,M.SM_CorrespondenceCon_IsBusinessContact
,M.SM_Owner_OwnershipStartDate
,M.SM_Owner_PurchaseDate
,M.SM_Owner_NameOnTitle
,M.SM_Owner_LastName
,M.SM_LevyCon_LastName
,M.SM_NoticeCon_LastName
,M.SM_CorrespondenceCon_LastName
,M.SM_Agent_ContactName
,M.SM_Agent_BusinessName
,M.SM_Agent_Title
,M.SM_Agent_OtherNames
,M.SM_Agent_BuildingName
,M.SM_Agent_StreetNumber
,M.SM_Agent_StreetName
,M.SM_Agent_Suburb
,M.SM_Agent_StateCode
,M.SM_Agent_PostCode
,M.SM_Agent_PoBox
,M.SM_Agent_Country
,M.SM_Agent_Mobile1
,M.SM_Agent_Mobile1_Note
,M.SM_Agent_Mobile2
,M.SM_Agent_Mobile2_Note
,M.SM_Agent_LandLine1
,M.SM_Agent_LandLine1_Note
,M.SM_Agent_LandLine2
,M.SM_Agent_LandLine2_Note
,M.SM_Agent_Email1
,M.SM_Agent_Email2
,M.SM_Agent_Email3
,M.SM_Agent_Fax
,M.SM_Agent_IsBusinessContact
,M.SM_Tenant_ContactName
,M.SM_Tenant_BusinessName
,M.SM_Tenant_Title
,M.SM_Tenant_OtherNames
,M.SM_Tenant_BuildingName
,M.SM_Tenant_StreetNumber
,M.SM_Tenant_StreetName
,M.SM_Tenant_Suburb
,M.SM_Tenant_StateCode
,M.SM_Tenant_PostCode
,M.SM_Tenant_PoBox
,M.SM_Tenant_Country
,M.SM_Tenant_Mobile1
,M.SM_Tenant_Mobile1_Note
,M.SM_Tenant_Mobile2
,M.SM_Tenant_Mobile2_Note
,M.SM_Tenant_LandLine1
,M.SM_Tenant_LandLine1_Note
,M.SM_Tenant_LandLine2
,M.SM_Tenant_LandLine2_Note
,M.SM_Tenant_Email1
,M.SM_Tenant_Email2
,M.SM_Tenant_Email3
,M.SM_Tenant_Fax
,M.SM_Tenant_IsBusinessContact
,M.SM_Other1_ContactName
,M.SM_Other1_BusinessName
,M.SM_Other1_Title
,M.SM_Other1_OtherNames
,M.SM_Other1_BuildingName
,M.SM_Other1_StreetNumber
,M.SM_Other1_StreetName
,M.SM_Other1_Suburb
,M.SM_Other1_StateCode
,M.SM_Other1_PostCode
,M.SM_Other1_PoBox
,M.SM_Other1_Country
,M.SM_Other1_Mobile1
,M.SM_Other1_Mobile1_Note
,M.SM_Other1_Mobile2
,M.SM_Other1_Mobile2_Note
,M.SM_Other1_LandLine1
,M.SM_Other1_LandLine1_Note
,M.SM_Other1_LandLine2
,M.SM_Other1_LandLine2_Note
,M.SM_Other1_Email1
,M.SM_Other1_Email2
,M.SM_Other1_Email3
,M.SM_Other1_Fax
,M.SM_Other1_IsBusinessContact
,M.SM_Other2_ContactName
,M.SM_Other2_BusinessName
,M.SM_Other2_Title
,M.SM_Other2_OtherNames
,M.SM_Other2_BuildingName
,M.SM_Other2_StreetNumber
,M.SM_Other2_StreetName
,M.SM_Other2_Suburb
,M.SM_Other2_StateCode
,M.SM_Other2_PostCode
,M.SM_Other2_PoBox
,M.SM_Other2_Country
,M.SM_Other2_Mobile1
,M.SM_Other2_Mobile1_Note
,M.SM_Other2_Mobile2
,M.SM_Other2_Mobile2_Note
,M.SM_Other2_LandLine1
,M.SM_Other2_LandLine1_Note
,M.SM_Other2_LandLine2
,M.SM_Other2_LandLine2_Note
,M.SM_Other2_Email1
,M.SM_Other2_Email2
,M.SM_Other2_Email3
,M.SM_Other2_Fax
,M.SM_Other2_IsBusinessContact
,M.SM_ExecutivePosition
,M.SM_LevyContactShare
,M.SM_NoticeContactShare
,M.SM_CorrespondenceContactShare
,M.SM_ExecutiveContactShare
,SM_Agent_ContactType = null
,M.SM_Is_AgentContact
,M.SM_Is_TenantContact
,M.SM_Is_Other1Contact
,M.SM_Is_Other2Contact
,M.SM_Lot_Liability
,M.SM_Lot_VotingEntitlement
,M.SM_ExecutivePositionStartDate
,M.SM_Owner_UnitNumber
,M.SM_Agent_UnitNo
,M.SM_Other2_UnitNumber
,M.SM_Other1_UnitNumber
,M.SM_Is_CommitteeContact
,M.SNG_CommitteeContactID
,M.SM_Committee_UnitNumber
,M.SM_Committee_ContactName
,M.SM_Committee_BusinessName
,M.SM_Committee_Title
,M.SM_Committee_OtherNames
,M.SM_Committee_BuildingName
,M.SM_Committee_StreetNumber
,M.SM_Committee_StreetName
,M.SM_Committee_Suburb
,M.SM_Committee_StateCode
,M.SM_Committee_PostCode
,M.SM_Committee_PoBox
,M.SM_Committee_Country
,M.SM_Committee_Mobile1
,M.SM_Committee_Mobile1_Note
,M.SM_Committee_Mobile2
,M.SM_Committee_Mobile2_Note
,M.SM_Committee_LandLine1
,M.SM_Committee_LandLine1_Note
,M.SM_Committee_LandLine2
,M.SM_Committee_LandLine2_Note
,M.SM_Committee_Email1
,M.SM_Committee_Email2
,M.SM_Committee_Email3
,M.SM_Committee_Fax
,M.SM_Committee_IsBusinessContact
,M.Batch
,M.Payment_Reference
,M.BankAccountNumber
,M.LotRef
,M.SM_RejectLevyReceipts
,M.LotSortingOrder
,M.OwnerPref
,M.AgentPref
,M.Email1_Pref
,M.Email2_Pref
,M.Email3_Pref
,M.SM_AgentLevyEmail
,M.LastReceiptDate
,M.SM_Other3ContactID
,M.SNG_Other3ContactID
,M.SM_Other3_ContactName
,M.SM_Other3_BusinessName
,M.SM_Other3_Title
,M.SM_Other3_OtherNames
,M.SM_Other3_BuildingName
,M.SM_Other3_StreetNumber
,M.SM_Other3_StreetName
,M.SM_Other3_Suburb
,M.SM_Other3_StateCode
,M.SM_Other3_PostCode
,M.SM_Other3_PoBox
,M.SM_Other3_Country
,M.SM_Other3_Mobile1
,M.SM_Other3_Mobile1_Note
,M.SM_Other3_Mobile2
,M.SM_Other3_Mobile2_Note
,M.SM_Other3_LandLine1
,M.SM_Other3_LandLine1_Note
,M.SM_Other3_LandLine2
,M.SM_Other3_LandLine2_Note
,M.SM_Other3_Email1
,M.SM_Other3_Email2
,M.SM_Other3_Email3
,M.SM_Other3_Fax
,M.SM_Other3_IsBusinessContact
,M.SM_Is_Other3Contact
,M.SM_Other3_UnitNumber

--select [Street Address],*
from [dbo].[syn_ERP_T_SNG_IMPORT_MasterData] M
LEFT JOIN [dbo].[T_SNG_IMPORT_MasterData] MA ON M.SM_Lot_Number = MA.SM_Lot_Number AND MA.SNG_PropertyID = @PropertyID
WHERE MA.ID IS NULL

--_DATA_MIGRATION_TEMP.[dbo].T_SNG_IMPORT_MasterData_Priorstrata_71304

--_DATA_MIGRATION_TEMP.[dbo].[T_SNG_IMPORT_MasterData_Priorstrata_15400]

--_DATA_MIGRATION_TEMP.[dbo].[T_SNG_IMPORT_MasterData_Priorstrata_6161]

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


