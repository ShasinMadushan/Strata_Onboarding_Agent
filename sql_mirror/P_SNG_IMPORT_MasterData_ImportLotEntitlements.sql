
CREATE PROCEDURE [dbo].[P_SNG_IMPORT_MasterData_ImportLotEntitlements]
    
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
 FROM F_SNG_Properties_L3_CORE(69)
 WHERE PropertyID = @PropertyID AND ManagingCompanyCode = @ManagingCompanyCode;
 
       
declare @Total_Voting_Entitlement INT,
   @Total_Lot_Liability INT

 select @Total_Voting_Entitlement = SUM(ISNULL(SM_Lot_VotingEntitlement,0))
 FROM [dbo].T_SNG_IMPORT_MasterData T
 where SNG_PropertyID = @PropertyID --AND SM_Owner_CurrentOwner = 1

 select @Total_Lot_Liability = SUM(ISNULL(SM_Lot_Liability,0))
 FROM [dbo].T_SNG_IMPORT_MasterData T
 where SNG_PropertyID = @PropertyID --AND SM_Owner_CurrentOwner = 1

 select @Total_Voting_Entitlement, @Total_Lot_Liability

  IF Exists(SELECT 1 from [dbo].[T_SNG_STRATA_Property_Entitlements] PE WHERE PropertyID = @PropertyID)
  BEGIN
   UPDATE PE
   SET PE.TotalEntitlement = @Total_Voting_Entitlement,
   PE.IsActive = case WHEN @Total_Voting_Entitlement > 0  THEN 1 ELSE 0 END
   --SELECT * 
   from 
   [dbo].[T_SNG_STRATA_Property_Entitlements] PE 
   WHERE PE.PropertyID =  @PropertyID and PE.PropEntTypeID = 1

    UPDATE PE
   SET PE.TotalEntitlement = @Total_Lot_Liability,
   PE.IsActive = case WHEN @Total_Lot_Liability > 0  THEN 1 ELSE 0 END
   --SELECT * 
   from 
   [dbo].[T_SNG_STRATA_Property_Entitlements] PE 
   WHERE PE.PropertyID =  @PropertyID and PE.PropEntTypeID = 2

  END
  ELSE
  BEGIN
   INSERT INTO [dbo].[T_SNG_STRATA_Property_Entitlements](PropEntTypeID, PropertyID, ScheduleDescription, IsActive, TotalEntitlement, LastEditUserID, LastEditDateTime)
   SELECT 1, @PropertyID,'Voting Entitlement', 1,@Total_Voting_Entitlement,69, GETDATE()
   UNION ALL
   SELECT 2, @PropertyID,'Lot Liability', 1,@Total_Lot_Liability,69, GETDATE()
  END


  IF(@Total_Voting_Entitlement > 0)
  BEGIN
   Insert into [dbo].[T_SNG_STRATA_Property_LotEntitlements](PropEntitlementID, LotID, LotEntAmount)
   select PE.PropEntitlementID, T.SNG_LotID, T.[SM_Lot_VotingEntitlement] --[SM_Lot_Liability]
   --PE.PropEntitlementID, L.LotID,UE.Entitlement
   from [dbo].[T_SNG_STRATA_Property_Entitlements] PE
   inner join [dbo].T_SNG_IMPORT_MasterData T ON PE.PropertyID = T.SNG_PropertyID
   left join [dbo].[T_SNG_STRATA_Property_LotEntitlements] le on le.lotid = T.SNG_LotID  and pe.PropEntitlementID = le.PropEntitlementID
   WHERE PE.ScheduleDescription = 'Voting Entitlement' and PE.PropertyID = @PropertyID --AND SM_Owner_CurrentOwner = 1
   and le.lotid is null
  END 
  IF(@Total_Lot_Liability > 0)
  BEGIN
  Insert into [dbo].[T_SNG_STRATA_Property_LotEntitlements](PropEntitlementID, LotID, LotEntAmount)
   select PE.PropEntitlementID, T.SNG_LotID, T.[SM_Lot_Liability]
   --PE.PropEntitlementID, L.LotID,UE.Entitlement
   from [dbo].[T_SNG_STRATA_Property_Entitlements] PE
   inner join [dbo].T_SNG_IMPORT_MasterData T ON PE.PropertyID = T.SNG_PropertyID
   left join [dbo].[T_SNG_STRATA_Property_LotEntitlements] le on le.lotid = T.SNG_LotID  and pe.PropEntitlementID = le.PropEntitlementID
   WHERE PE.ScheduleDescription = 'Lot Liability' and PE.PropertyID = @PropertyID --AND SM_Owner_CurrentOwner = 1
   and le.lotid is null
  END
 




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

