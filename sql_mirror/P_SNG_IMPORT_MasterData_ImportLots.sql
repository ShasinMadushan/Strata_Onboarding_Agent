
CREATE PROCEDURE [dbo].[P_SNG_IMPORT_MasterData_ImportLots]
    
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
 WHERE PropertyID = @PropertyID AND ManagingCompanyCode =@ManagingCompanyCode;

 IF(@PlanNumber IS NULL)
 RETURN;
 

     update A
  set LotSortingOrder = Rownum
  --
  --select *
  from
  (
  select  ROW_NUMBER() OVER(PARTITION BY plannumber ORDER BY  cast(SM_Lot_Number as int)) as Rownum ,*
  from [dbo].[T_SNG_IMPORT_MasterData]
  where plannumber = @PlanNumber  and SM_Lot_Number not like '%[A-Za-z]%'
  and CompanyCode = @ManagingCompanyCode -- not in( 'Res1')
  and isnumeric(SM_Lot_Number) = 1
  ) A


  insert into [dbo].[T_SNG_Import_LotDetails] (CompanyCode, Batch, PlanNumber, LotNo, UnitNo,SNG_PropertyID )
  select CompanyCode =@ManagingCompanyCode, Batch=@ManagingCompanyCode, PlanNumber = @PlanNumber, LotNo = SM_Lot_Number, UnitNo = SM_Lot_Unit_Number,SNG_PropertyID  =m.SNG_PropertyID
   FROM [dbo].[T_SNG_IMPORT_MasterData] m
   left join [T_SNG_Import_LotDetails] l on m.SM_Lot_Number = l.LotNo and l.plannumber =@PlanNumber 
   where m.PlanNumber = @PlanNumber and l.LotNo is null ;


  

   update L
   set l.SNG_LotID = ll.LotID, l.SNG_LotAddressID = ll.LotAddressID
   from [dbo].[T_SNG_Import_LotDetails] l
   inner join [dbo].F_SNG_Properties_L3_CORE(69) p on p.PropertyID = l.SNG_PropertyID 
   inner join [dbo].T_SNG_Lots ll on ll.Lot_Number = l.LotNo and p.PropertyID = ll.PropertyID
   where p.PlanNumber = @PlanNumber and p.ManagingCompanyCode = @ManagingCompanyCode AND L.SNG_LotID IS NULL;

   DECLARE @ID INT;



DECLARE db_cursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR 
SELECT ID
FROM [dbo].[T_SNG_Import_LotDetails] 
WHERE SNG_LotID IS NULL 
AND CompanyCode =@ManagingCompanyCode
and PlanNumber = @PlanNumber

order by id


OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @ID

WHILE @@FETCH_STATUS = 0  
BEGIN  


DECLARE @SNG_LotID INT = NULL;
DECLARE @SNG_PropertyID INT = NULL;

DECLARE @UserID int = 69;



SELECT 
@SNG_LotID = SNG_LotID
FROM [dbo].[T_SNG_Import_LotDetails] 
WHERE [ID] = @ID;

SELECT @SNG_PropertyID = P.PropertyID
FROM dbo.F_SNG_Properties_L3_core(69) P
WHERE P.ManagingCompanyCode = @ManagingCompanyCode
AND PlanNumber = @PlanNumber

PRINT @SNG_LotID

IF (@SNG_LotID IS NULL)
BEGIN

 DECLARE  @AddressID INT = NULL,    
    @Lot_Number VARCHAR(20),
    @Lot_Number_Orig VARCHAR(20),
    @LotType VARCHAR(10) = 1,
    @BuildingName VARCHAR(300),
    @UnitNumber VARCHAR(50),
    @StreetNumber VARCHAR(20),
    @StreetName VARCHAR(200),
    @PostCode VARCHAR(8),
    @Suburb VARCHAR(100),
    @StateCode VARCHAR(3),
    @AddressType VARCHAR(10),
    @IsActive INT = 1,
    @CountryCode VARCHAR(3) ,
    @ReturnAddressID INT,
    @ReturnLotId INT,    
    @OwnerOccupied  bit,
    @Lot_Notes VARCHAR(MAX) = NULL,
    @latitude DECIMAL(12,9),
    @longitude DECIMAL(12,9),
    @placeurl  VARCHAR(5000),
    @LotSortingOrder [numeric](18, 4),
    @MasterID INT
   
 select 
 @Lot_Number = T.LotNo,-- L.lLotNumber,
 @UnitNumber = T.UnitNo , --T.SM_Lot_Unit_Number,--
 @BuildingName = NULL,-- SA.sBuildingName,
 @StreetNumber =  M.SM_Lot_StreetNumber,--SA.sStreetNumberPrefix + IIF(SA.lStreetNumber = 0,'',cast(SA.lStreetNumber AS VARCHAR(10))) + SA.sStreetNumberSuffix,
 @StreetName = M.SM_Lot_StreetName,--SA.sStreet,
 @Suburb = M.SM_Lot_Suburb,--SA.sTown,
 @StateCode = M.SM_Lot_StateCode,--SA.sState,
 @PostCode = M.SM_Lot_PostCode ,--SA.sPostCode,
 @OwnerOccupied = m.SM_Lot_OwnerOccupied,--CASE WHEN T.SM_Lot_OwnerOccupied = 'Y' THEN 1 WHEN T.SM_Lot_OwnerOccupied = 'N' THEN 0  END,--L.bOwnerOccupied,
 @PlanNumber = T.PlanNumber,--OC.sPlanNumber
 @PropertyID = @SNG_PropertyID,
 @Lot_Notes = NULL,
 @LotSortingOrder = LotSortingOrder,
 @MasterID = M.ID
 --select *
 FROM 
  [dbo].[T_SNG_Import_LotDetails]  T
  INNER JOIN [dbo].[T_SNG_IMPORT_MasterData] M on TRIM(M.PlanNumber) = TRIM(T.PlanNumber) and TRIM(T.LotNo) = TRIM(M.SM_Lot_Number)
  --INNER JOIN dbo.T_SNG_Properties P on TRIM(P.PlanNumber) = TRIM(T.PlanNumber)
  --INNER JOIN dbo.T_SNG_Addresses A on A.AddressID = P.PropertyAddressID
  WHERE T.ID = @ID


 
  



 IF @PropertyID IS NULL
  print 'Property ID IS NULL'
  --BREAK;
 ELSE
 BEGIN

 SELECT @AddressID = AddressID
 FROM T_SNG_Addresses
 WHERE ISNULL([BuildingName],'') = ISNULL(@BuildingName,'') AND ISNULL(UnitNumber,'') = ISNULL(@UnitNumber,'') 
 AND ISNULL(StreetNumber,'') = ISNULL(@StreetNumber,'') AND ISNULL(StreetName,'') = ISNULL(@StreetName,'') 
 AND ISNULL(Suburb,'') = ISNULL(@Suburb,'')  AND ISNULL(StateCode,'') = ISNULL(@StateCode,'')
 AND ISNULL(CountryCode,'') = ISNULL(@CountryCode,'') AND ISNULL(PostCode,'') = ISNULL(@PostCode,'')
 
 
 

  EXEC [dbo].[P_SNG_MANUALLOT_AddAddresses_DL] 
   @AddressID,
   @PropertyID,
   @UserID,
   @Lot_Number,
   @Lot_Number_Orig,
   @LotType,
   @BuildingName,
   @UnitNumber,
   @StreetNumber,
   @StreetName,
   @PostCode,
   @Suburb,
   @StateCode,
   @AddressType,
   @IsActive,
   @OwnerOccupied,
   @CountryCode,
   @latitude,
   @longitude,
   @placeurl,
   @ManagingCompanyCode,
   @ReturnAddressID OUTPUT,
   @ReturnLotId OUTPUT,
   @LotSortingOrder

   
  
              
               Update dbo.T_SNG_Lots
    SET IsOwnerOccupied = @OwnerOccupied
    WHERE LotID = @ReturnLotId
        
  
   IF @Lot_Notes IS NOT NULL
   BEGIN
    Update dbo.T_SNG_Lots
    SET Lot_Note = @Lot_Notes,IsOwnerOccupied = @OwnerOccupied
    WHERE LotID = @ReturnLotId
   END

   UPDATE [dbo].[T_SNG_Import_LotDetails] 
   SET SNG_LotID = @ReturnLotId ,SNG_LotAddressID = @ReturnAddressID
   WHERE ID = @ID

  

   UPDATE M
   SET SNG_LotID = @ReturnLotId , SNG_LotAddressID = @ReturnAddressID
   FROM [dbo].[T_SNG_IMPORT_MasterData] M
   WHERE ID = @MasterID

  END
END -- LOT HAS BEEN CREATED







 FETCH NEXT FROM db_cursor INTO @ID  
END 

CLOSE db_cursor  
DEALLOCATE db_cursor 


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

