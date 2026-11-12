
CREATE PROCEDURE [dbo].[P_SNG_PROPERTY_AddUpdateOwners_V2] 
 @ManagingCompanyCode varchar(30),
 @CompanyID int,
 @LotID int,
 @IsActiveLot varchar(10),
 @OwnerID int,
 @NameOnTitle varchar(max), 
 @OwnershipStartDate datetime,
 @PurchaseDate datetime,
 @Positions varchar(max),
 @PositionStartDate datetime,
 @IsCommitteeMemeber varchar(10),
 @NameOnTitleChanged int,
 @UserID int,
 @LotAddress int,
 @OwnerOccupied varchar(10),
 @ReturnOwnerId INT OUTPUT,
 @OD_Interest_Charging_Enabled VARCHAR(6), 
 @OD_WriteOff_Unpaid_Interest VARCHAR(6), 
 @OD_WriteOff_Unpaid_Interest_Limit VARCHAR(6), 
 @OD_Write_off_interest_when_paid_in_full VARCHAR(6), 
 @OD_Write_off_interest_when_paid_in_full_Limit VARCHAR(6),
 @LotNote VARCHAR(MAX),
 @lotType INT,
 @lotused VARCHAR(10)

AS

BEGIN
 SET NOCOUNT ON 
 SET XACT_ABORT ON  
 
 BEGIN TRANSACTION;
 BEGIN TRY
 
 DECLARE --@CompanyID int,
   @LotOwnerID int,
   @RecordCount int,
   @LegalEntityID int,
   @ContactID int,
   @ExistingUser int,
   @SourceKey VARCHAR(MAX),
   @PreviousLotOwnerID INT,
   @PreviousLotLegalEntityID INT;   
 
 SELECT @SourceKey = 'Plan:'+ ISNULL(P.PlanNumber,'') + '-Lot:' + ISNULL(L.Lot_Number,'')
 FROM   [dbo].[F_SNG_Lots_L2](@UserID) L
     INNER JOIN [dbo].[F_SNG_Properties_L3](@UserID) P ON P.PropertyID = L.PropertyID
 WHERE  L.LotID = @LotID;

 SET @Positions = CASE @IsCommitteeMemeber WHEN 'on' THEN @Positions ELSE '' END;
 
 IF (ISNULL(@OwnerID,0) =0 OR ISNULL(@OwnerID,0)=-1)
 BEGIN
  
  INSERT INTO T_SNG_Owners (StartDate, PurchaseDate, OwnerName_OnTitle, IsActive,  LastEditUser, LastEditDate,AssignedLotID)
  VALUES( @OwnershipStartDate, @PurchaseDate, @NameOnTitle, 1,  @UserID, GETDATE(),@LotID)
  SELECT @OwnerID = SCOPE_IDENTITY();

  SET @ReturnOwnerId = @OwnerID;


 


  DECLARE @NewContactID INT;

  --01 check is Owner occupied 
  --IF(@OwnerOccupied='on') --if the owner occupied then owner address is lot address. if not make it null so that a different address can be selected.
  -- BEGIN

  --  INSERT INTO [dbo].[T_SNG_Contacts] (ContactName,AddressID,LastModifiedUserID,LastModified,CompanyCode)
  --  VALUES (@NameOnTitle, IIF(@OwnerOccupied='on', @LotAddress, NULL) ,@UserID,GETDATE(),@ManagingCompanyCode)
      
  --  SET @NewContactID = Scope_Identity();

  --  INSERT INTO[dbo].[T_SNG_STRATA_OwnerContacts](OwnerID,ContactTypeCode,ContactID, LastModified, LastModifiedUserID)
  --  VALUES(@ReturnOwnerId,'OWNER-MAIN',@NewContactID, GETDATE(), @UserID)
   
  -- END
  ----ELSE
  -- BEGIN
  --  INSERT INTO [dbo].[T_SNG_Contacts] (ContactName,AddressID,LastModifiedUserID,LastModified,CompanyCode)
  --  VALUES (@NameOnTitle,@LotAddress,@UserID,GETDATE(),@ManagingCompanyCode)
      
  --  SET @NewContactID = Scope_Identity();

  --  INSERT INTO[dbo].[T_SNG_STRATA_OwnerContacts](OwnerID,ContactTypeCode,ContactID, LastModified, LastModifiedUserID)
  --  VALUES(@ReturnOwnerId,'TENANT',@NewContactID, GETDATE(), @UserID)
  -- END



  INSERT INTO T_SNG_LegalEntities (OwnerID, EntityType, LegalEntityName, SourceKey) VALUES (@OwnerID, 'Owner', @NameOnTitle, @SourceKey)
  SELECT @LegalEntityID = SCOPE_IDENTITY();

  UPDATE [dbo].[T_SNG_Owners]
  SET LegalEntityID = @LegalEntityID
  WHERE OwnerID = @OwnerID;

  SELECT @PreviousLotOwnerID = OwnerID
  FROM T_SNG_Lots
  WHERE LotID = @LotID;

  SELECT @PreviousLotLegalEntityID = LegalEntityID
  FROM T_SNG_Owners
  WHERE OwnerID = @PreviousLotOwnerID;

  EXEC [dbo].[P_SNG_PROPERTY_AddUpdateOwners_TransferOwner]
    @SNG_UserID =@UserID,
    @ManagingCompanyCode =@ManagingCompanyCode,
    @LotID =@LotID,  
    @PreviousLotOwnerID =@PreviousLotOwnerID,
    @NewLotOwnerID =@OwnerID;

  --UPDATE [dbo].[T_SNG_ERP_GL_Header]
  --SET Related_LegalEntityID = @LegalEntityID
  --WHERE Related_LegalEntityID = @PreviousLotLegalEntityID
  --AND TransactionTime > @OwnershipStartDate;

  --UPDATE  T_SNG_STRATA_Levy_Schedule_Details
  --SET LevyPosted_OwnerID = @OwnerID
  --WHERE LevyPosted_OwnerID = @PreviousLotOwnerID
  --AND CalculatedAppliedDate > @OwnershipStartDate;

  UPDATE T_SNG_Lots
  SET OwnerID = @OwnerID
  WHERE LotID = @LotID;
 END
 
 UPDATE T_SNG_Lots
 SET IsActiveLot = CASE @IsActiveLot WHEN 'on' THEN 1 ELSE 0 END,
  LotAddressID = @LotAddress,
  Lot_Note  = @LotNote,
  [LotType] = @lotType,
  [LotUsed] = @lotused,
  IsOwnerOccupied = CASE @OwnerOccupied WHEN 'on' THEN 1 ELSE 0 END
 WHERE LotID = @LotID

 --select * FROM [dbo].[T_SNG_Owners]
 --SELECT * FROM [T_SNG_Lots]

 UPDATE [dbo].[T_SNG_Owners]
 SET 
  StartDate = @OwnershipStartDate, 
  PurchaseDate = @PurchaseDate, 
  IsActive = 1, 
  LastEditUser = @UserID, 
  AssignedLotID = @LotID,
  LastEditDate =  GETDATE(),
  OD_Interest_Charging_Enabled = @OD_Interest_Charging_Enabled, 
  OD_WriteOff_Unpaid_Interest = @OD_WriteOff_Unpaid_Interest, 
  OD_WriteOff_Unpaid_Interest_Limit = @OD_WriteOff_Unpaid_Interest_Limit, 
  OD_Write_off_interest_when_paid_in_full = @OD_Write_off_interest_when_paid_in_full, 
  OD_Write_off_interest_when_paid_in_full_Limit = @OD_Write_off_interest_when_paid_in_full_Limit
 WHERE
  OwnerID = @OwnerID;

 IF @NameOnTitleChanged = 1
 BEGIN
  UPDATE [dbo].[T_SNG_Owners]
  SET OwnerName_OnTitle = @NameOnTitle,
   --StartDate = @OwnershipStartDate, 
   --PurchaseDate = @PurchaseDate, 
   --IsActive = 1, 
   LastEditUser = @UserID, 
   LastEditDate =  GETDATE()
  WHERE
   OwnerID = @OwnerID; 
 END
 
 --SELECT * FROM T_SNG_STRATA_Committee_Members 
 DELETE FROM T_SNG_STRATA_Committee_Members
 WHERE OwnerID = @OwnerID 

 IF ISNULL(@Positions,'') <> ''
 BEGIN
  --print 'z'
  INSERT INTO T_SNG_STRATA_Committee_Members (OwnerID, CommitteePositionID, PositionStartDate)
  SELECT @OwnerID, A.Item, @PositionStartDate
  FROM (SELECT Item FROM [dbo].[F_SNG_UTILS_SplitString](@Positions, ','))A
  WHERE ISNULL(A.Item,'')<>'';
 END

 IF @@TRANCOUNT > 0
  COMMIT TRANSACTION;
      
 END TRY

 BEGIN CATCH
  declare 
   @ErrorMessage varchar(1000),@ErrorNumber int,@ErrorSeverity int,@ErrorState int,@ErrorProcedure varchar(300),@ErrorLine int;
   
  SELECT    
   @ErrorMessage = ERROR_MESSAGE(),@ErrorNumber = ERROR_NUMBER(),@ErrorSeverity = ERROR_SEVERITY(),
   @ErrorState = ERROR_STATE(),@ErrorProcedure = ERROR_PROCEDURE(),@ErrorLine = ERROR_LINE();

  IF @@TRANCOUNT > 0
   BEGIN
    ROLLBACK TRANSACTION;
    PRINT 'ROLLBACK TRANSACTION';
   END

  exec [dbo].[p_SNG_T_SNG_SYSTEM_SQL_Errors_Insert] 
   @ErrorMessage = @ErrorMessage,
   @ErrorNumber = @ErrorNumber,
   @ErrorSeverity = @ErrorSeverity,
   @ErrorState = @ErrorState,
   @ErrorProcedure = @ErrorProcedure,
   @ErrorLine = @ErrorLine
  
  RAISERROR (@ErrorMessage,
       @ErrorSeverity,
       @ErrorState )
       
 END CATCH;

END










