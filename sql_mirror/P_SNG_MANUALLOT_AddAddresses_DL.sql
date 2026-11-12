CREATE PROCEDURE [dbo].[P_SNG_MANUALLOT_AddAddresses_DL] @AddressID       INT,
                                                     @PropertyID      INT,
                                                     @UserID          INT,
                                                     @Lot_Number      VARCHAR(20),
                                                     @Lot_Number_Orig VARCHAR(20),
                                                     @LotType         VARCHAR(10),
                                                     @BuildingName    VARCHAR(300),
                                                     @UnitNumber      VARCHAR(50),
                                                     @StreetNumber    VARCHAR(20),
                                                     @StreetName      VARCHAR(200),
                                                     @PostCode        VARCHAR(8),
                                                     @Suburb          VARCHAR(100),
                                                     @StateCode       VARCHAR(3),
                                                     @AddressType     VARCHAR(10),
                                                     @IsActive        INT,
                                                     @IsOwnerOccupied INT,
                                                     @CountryCode     VARCHAR(3),

              @latitude        DECIMAL(12,9),
              @longitude    DECIMAL(12,9),
              @placeurl        VARCHAR(5000),

              @ManagingCompanyCode  VARCHAR(100),
                                                     @ReturnAddressID INT OUTPUT,
                                                     @ReturnLotId     INT OUTPUT,
              @LotSortingOrder [numeric](18, 4)
AS
    BEGIN
        SET NOCOUNT ON;
        SET XACT_ABORT ON;

        BEGIN TRANSACTION;
        BEGIN TRY

            DECLARE @Output_Error VARCHAR(MAX) = '';

            PRINT 'P_SNG_MANUALLOT_AddAddresses';
            PRINT @PropertyID;
            PRINT @Lot_Number;

            DECLARE @AddressCount INT = 0,
                    @OwnerID      INT,
                    @Count        INT,
     @LotCount INT;

            --SELECT @AddressID = AddressID 
            --FROM [dbo].[F_SNG_Lots_L2](@UserID) L
            -- INNER JOIN [dbo].[F_SNG_Addresses_L3](@UserID) A ON L.LotAddressID = A.AddressID
            --WHERE PropertyID = @PropertyID AND L.LotID = @Lot_Number_Orig 
            SET @Count =
            (
                SELECT COUNT(*)
                FROM [dbo].[F_SNG_Addresses_L3](@UserID)
                WHERE AddressID = @AddressID
            );

            SET @ReturnAddressID = @AddressID;

            IF(@Count = 0)
                BEGIN
                    PRINT 'insert';


                    INSERT INTO T_SNG_Addresses
                    (BuildingName,
                     UnitNumber,
                     StreetNumber,
                     StreetName,
                     Suburb,
                     StateCode,
                     CountryCode,
                     PostCode,
      AddressType,
                     LastModifiedUserID,
                     LastModified,
      CompanyCode,
      Longitude,
      Latitude,
      PlaceUrl
                    )
                           SELECT @BuildingName,
                                  @UnitNumber,
                                  @StreetNumber,
                                  @StreetName,
                                  @Suburb,
                                  @StateCode,
                                  @CountryCode,
                                  @PostCode,
          'AUS',
                                  @UserID,
                                  GETDATE(),
          @ManagingCompanyCode,
          @longitude,
          @latitude,
          @placeurl;
                  
                    SET @AddressID = SCOPE_IDENTITY();
                    SET @ReturnAddressID = @AddressID;

                    IF(@Lot_Number_Orig IS NULL
                       OR @Lot_Number_Orig = ''
                       OR @Lot_Number_Orig = 0)
                        BEGIN

                            INSERT INTO T_SNG_Lots
                            (PropertyID,
                             OwnerID,
                             Notes,
                             LotAddressID,
                             Lot_Number,
                             LotStartDate,
                             IsActiveLot,
                             IsOwnerOccupied,
        LotSortingOrder
                            )
                                   SELECT @PropertyID,
                                          NULL,
                                          NULL,
                                          @AddressID,
                                          @Lot_Number,
                                          GETDATE(),
                                          @IsActive,
                                          @IsOwnerOccupied,
            @LotSortingOrder

                            SET @Lot_Number_Orig = SCOPE_IDENTITY();
                            SET @ReturnLotId = @Lot_Number_Orig;       

         SELECT @LotCount = COUNT(*)
         FROM dbo.F_SNG_Properties_L3(@UserID) P
         INNER JOIN dbo.T_SNG_Lots L on P.PropertyID = L.PropertyID
         where P.PropertyID = @PropertyID and l.IsActiveLot = 1;

         UPDATE  dbo.T_SNG_Properties
         SET LotCount = @LotCount
         WHERE PropertyID = @PropertyID;      


                    END;
                        ELSE
                        BEGIN
                            UPDATE T_SNG_Lots
                              SET
                                  LotAddressID = @AddressID,
                                  Lot_Number = @AddressID,
                                  IsActiveLot = @IsActive,
                                  IsOwnerOccupied = @IsOwnerOccupied
                            WHERE PropertyID = @PropertyID
                                  AND LotID = @Lot_Number_Orig;
                            SET @ReturnLotId = @Lot_Number_Orig;       

         SELECT @LotCount = COUNT(*)
         FROM dbo.F_SNG_Properties_L3(@UserID) P
         INNER JOIN dbo.T_SNG_Lots L on P.PropertyID = L.PropertyID
         where P.PropertyID = @PropertyID and l.IsActiveLot = 1;

         UPDATE  dbo.T_SNG_Properties
         SET LotCount = @LotCount
         WHERE PropertyID = @PropertyID;

                    END;
            END;
                ELSE
                BEGIN

                    PRINT 'update';
     IF EXISTS(SELECT * FROM [dbo].[F_SNG_Lots_L2](@UserID) WHERE PropertyID  = @PropertyID AND Lot_Number = @Lot_Number)
     BEGIN

                    UPDATE T_SNG_Lots
                      SET
                          Lot_Number = @Lot_Number,
                          IsActiveLot = @IsActive,
                          IsOwnerOccupied = @IsOwnerOccupied
                    WHERE PropertyID = @PropertyID
                          AND LotID = @Lot_Number_Orig;
                    SET @ReturnLotId = @Lot_Number_Orig;

       SELECT @LotCount = COUNT(*)
         FROM dbo.F_SNG_Properties_L3(@UserID) P
         INNER JOIN dbo.T_SNG_Lots L on P.PropertyID = L.LotID
         where P.PropertyID = @PropertyID and l.IsActiveLot = 1;

         UPDATE  dbo.T_SNG_Properties
         SET LotCount = @LotCount
         WHERE PropertyID = @PropertyID;

                    UPDATE T_SNG_Addresses
                    SET
                          BuildingName = @BuildingName,
                          UnitNumber = @UnitNumber,
                          StreetName = @StreetName,
                          StreetNumber = @StreetNumber,
                          Suburb = @Suburb,
                          StateCode = @StateCode,
                          CountryCode = @CountryCode,
                          PostCode = @PostCode,
                          --AddressType = @AddressType, 
                          --EntityType = @LotType,
                          LastModifiedUserID = @UserID,
                          LastModified = GETDATE(),
        CompanyCode  = @ManagingCompanyCode

                    WHERE AddressID = @AddressID;

     SET @ReturnAddressID = @AddressID;

     END
     ELSE
     BEGIN
      INSERT INTO T_SNG_Lots
                            (PropertyID,
                             OwnerID,
                             Notes,
                             LotAddressID,
                             Lot_Number,
                             LotStartDate,
                             IsActiveLot,
                             IsOwnerOccupied,
        LotSortingOrder
                            )
                                   SELECT @PropertyID,
                                          NULL,
                                          NULL,
                                          @AddressID,
                                          @Lot_Number,
                                          GETDATE(),
                                          @IsActive,
                                          @IsOwnerOccupied,
            @LotSortingOrder;


      SET @Lot_Number_Orig = SCOPE_IDENTITY();
      SET @ReturnLotId = @Lot_Number_Orig;       

       SELECT @LotCount = COUNT(*)
       FROM dbo.F_SNG_Properties_L3(@UserID) P
       INNER JOIN dbo.T_SNG_Lots L on P.PropertyID = L.PropertyID
       where P.PropertyID = @PropertyID and l.IsActiveLot = 1;

       UPDATE  dbo.T_SNG_Properties
       SET LotCount = @LotCount
       WHERE PropertyID = @PropertyID; 

      SET @ReturnAddressID = @AddressID;

     END
     


                    

            END;

            IF @@TRANCOUNT > 0
                COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage   VARCHAR(1000),
                    @ErrorNumber    INT,
                    @ErrorSeverity  INT,
                    @ErrorState     INT,
                    @ErrorProcedure VARCHAR(300),
                    @ErrorLine      INT;

            SELECT @ErrorMessage = ERROR_MESSAGE(),
                   @ErrorNumber = ERROR_NUMBER(),
                   @ErrorSeverity = ERROR_SEVERITY(),
                   @ErrorState = ERROR_STATE(),
                   @ErrorProcedure = ERROR_PROCEDURE(),
                   @ErrorLine = ERROR_LINE();

            IF @@TRANCOUNT > 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    PRINT 'ROLLBACK TRANSACTION';
            END;

            EXEC [dbo].[p_SNG_T_SNG_SYSTEM_SQL_Errors_Insert]
                 @ErrorMessage = @ErrorMessage,
                 @ErrorNumber = @ErrorNumber,
                 @ErrorSeverity = @ErrorSeverity,
                 @ErrorState = @ErrorState,
                 @ErrorProcedure = @ErrorProcedure,
                 @ErrorLine = @ErrorLine;

            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        END CATCH;

    END;

       











