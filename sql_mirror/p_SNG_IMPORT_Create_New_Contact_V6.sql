
CREATE PROC [dbo].[p_SNG_IMPORT_Create_New_Contact_V6]
 @ID INT,
 @UserID INT,
 @ManagingCompanyCode VARCHAR(30),
 @SM_ContactID INT,
 @ContactType VARCHAR(20),
 @OUT_SNG_ContactID INT OUTPUT
As
BEGIN

 DECLARE  @AddressID INT,
    @PropertyID INT,
    @Lot_Number VARCHAR(20),
    @Lot_Number_Orig VARCHAR(20),
    @LotType VARCHAR(10),
    @BuildingName VARCHAR(300),
    @UnitNumber VARCHAR(50),
    @StreetNumber VARCHAR(100),
    @StreetName VARCHAR(200),
    @PostCode VARCHAR(100),
    @Suburb VARCHAR(100),
    @StateCode VARCHAR(100),
    @AddressType VARCHAR(10),
    @IsActive INT,
    @CountryCode VARCHAR(3) ,
    @ReturnAddressID INT,
    @ReturnLotId INT,
    @PlanNumber VARCHAR(50),
    @OwnerOccupied  VARCHAR(1)

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
   @SNG_UserID INT = @UserID,
   @CompanyCode VARCHAR(20)= @ManagingCompanyCode,
   @Country VARCHAR(200),
   @AddressIdOut INT = NULL,
   @ReturnMessage VARCHAR(MAX)= NULL ,
   @latitude        DECIMAL(12,9)= NULL ,
   @longitude    DECIMAL(12,9)= NULL ,
   @placeurl        VARCHAR(5000)= NULL ,
   @ComType   VARCHAR(30),
   @Lot_ID   INT

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
   @ChangeRequestFiles VARCHAR(5000) = NULL,
   --@ComType VARCHAR(50)= NULL,
   @LotGUID VARCHAR(50)= NULL,
   @OtherNames VARCHAR(200) = NULL,
   @ContactId INT= NULL,
   @IsbusinessContact Bit = NULL,
   @ContactIdOut INT = NULL,
   @Response VARCHAR(MAX) = NULL

   BEGIN -- Create new contact
    SELECT @BuildingName = NULL, @UnitNumber = NULL, @StreetName = NULL, @PostCode = NULL, @Suburb = NULL, @StateCode = NULL, @CountryCode = NULL, @AddressId = NULL

    SELECT @StreetNo = NULL,   
      @PoBox = NULL,
      @Line1 = NULL,
      @Line2 = NULL,
      @Line3 = NULL,
      @Line4 = NULL,
      @Line5 = NULL,
      @AusType    = 'AUS',
      @PoboxType  = NULL,
      @InterAdds  = NULL,
      @PostCodePo = NULL,
      @SuburbPo   = NULL,
      @StateCodePo= NULL,
      @SNG_UserID = 69,
      @CompanyCode = @ManagingCompanyCode,
      @Country = NULL,
      @AddressIdOut = NULL,
      @ReturnMessage = NULL 

    SELECT  @FirstName  = NULL,
      @MiddleName = NULL,
      @LastName   = NULL,
      @ContactName = NULL,
      @Mobile = NULL,
      @Mobile_Notes = NULL,
      @Mobile2 = NULL,
      @Mobile2_Notes = NULL,
      @LandLine1 = NULL,
      @LandLine1_Notes = NULL,
      @LandLine2 = NULL,
      @LandLine2_Notes = NULL,
      @Email1 = NULL,
      @Email2 = NULL,
      @Email3 = NULL,
      @Fax = NULL,
      @Title = NULL,
      @BusinessName  = NULL,
      @OtherNames  = NULL,
      @ContactId = NULL,
      @ContactIdOut = NULL,
      @Response = NULL

 --     [SM_Owner_BuildingName],
 --[SM_Owner_StreetNumber],
 --[SM_Owner_StreetName],
 --[SM_Owner_Suburb],
 --[SM_Owner_StateCode],
 --[SM_Owner_PostCode],
 --[SM_Owner_PoBox],
 --[SM_Owner_Country],
 --[SM_Owner_FirstName],
 --[SM_Owner_ContactName],
 --[SM_Owner_Mobile1],
 --[SM_Owner_Mobile1_Note], 
 --[SM_Owner_Mobile2], 
 --[SM_Owner_Mobile2_Note], 
 --[SM_Owner_LandLine1],
 --[SM_Owner_LandLine1_Note],
 --[SM_Owner_LandLine2],
 --[SM_Owner_LandLine2_Note],
 --[SM_Owner_Email1],
 --[SM_Owner_Email2],
 --[SM_Owner_Email3],
 --[SM_Owner_Fax],
 --[SM_Owner_Title],
 --[SM_Owner_BusinessName],
 --[SM_Owner_OtherNames],

      SELECT  @BuildingName  = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_BuildingName WHEN 'OTHER1' THEN T.SM_Other1_BuildingName WHEN 'OTHER2' THEN T.SM_Other2_BuildingName WHEN 'AGENT' THEN T.SM_Agent_BuildingName WHEN 'TENANT' THEN T.SM_Tenant_BuildingName WHEN 'COMMITTEE' THEN T.SM_Committee_BuildingName  END, 
      @UnitNumber = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_UnitNumber  WHEN 'AGENT' THEN T.SM_Agent_UnitNo WHEN 'OTHER1' THEN T.SM_Other1_UnitNumber WHEN 'OTHER2' THEN T.SM_Other2_UnitNumber WHEN 'COMMITTEE' THEN T.SM_Committee_UnitNumber END,
      @StreetNo = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_StreetNumber WHEN 'OTHER1' THEN T.SM_Other1_StreetNumber WHEN 'OTHER2' THEN T.SM_Other2_StreetNumber WHEN 'AGENT' THEN T.SM_Agent_StreetNumber WHEN 'TENANT' THEN T.SM_Tenant_StreetNumber  WHEN 'COMMITTEE' THEN T.SM_Committee_StreetNumber END, 
      @StreetName = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_StreetName WHEN 'OTHER1' THEN T.SM_Other1_StreetName WHEN 'OTHER2' THEN T.SM_Other2_StreetName WHEN 'AGENT' THEN T.SM_Agent_StreetName WHEN 'TENANT' THEN T.SM_Tenant_StreetName WHEN 'COMMITTEE' THEN T.SM_Committee_StreetName END, 
      @Suburb = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Suburb WHEN 'OTHER1' THEN T.SM_Other1_Suburb WHEN 'OTHER2' THEN T.SM_Other2_Suburb WHEN 'AGENT' THEN T.SM_Agent_Suburb WHEN 'TENANT' THEN T.SM_Tenant_Suburb WHEN 'COMMITTEE' THEN T.SM_Committee_Suburb END, 
      @StateCode = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_StateCode WHEN 'OTHER1' THEN T.SM_Other1_StateCode WHEN 'OTHER2' THEN T.SM_Other2_StateCode WHEN 'AGENT' THEN T.SM_Agent_StateCode WHEN 'TENANT' THEN T.SM_Tenant_StateCode  WHEN 'COMMITTEE' THEN T.SM_Committee_StateCode END, 
      @PostCode = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_PostCode WHEN 'OTHER1' THEN T.SM_Other1_PostCode WHEN 'OTHER2' THEN T.SM_Other2_PostCode WHEN 'AGENT' THEN T.SM_Agent_PostCode WHEN 'TENANT' THEN SM_Tenant_PostCode WHEN 'COMMITTEE' THEN T.SM_Committee_PostCode END, 
      @ContactName = CASE @ContactType WHEN 'OWNER' THEN ISNULL(T.SM_Owner_ContactName,'') WHEN 'OTHER1' THEN ISNULL(SM_Other1_OtherNames,T.SM_Other1_ContactName) WHEN 'OTHER2' THEN ISNULL(SM_Other2_OtherNames,T.SM_Other2_ContactName) WHEN 'AGENT' THEN ISNULL(SM_Agent_OtherNames, T.SM_Agent_ContactName) WHEN 'TENANT' THEN ISNULL(T.SM_Tenant_ContactName,'')  WHEN 'COMMITTEE' THEN ISNULL(T.SM_Committee_ContactName,'') END, 
      @FirstName = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_FirstName  END, 
      @LastName = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_LastName END, 
      @OtherNames = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_OtherNames WHEN 'OTHER1' THEN T.SM_Other1_OtherNames WHEN 'OTHER2' THEN T.SM_Other2_OtherNames WHEN 'AGENT' THEN T.SM_Agent_OtherNames WHEN 'TENANT' THEN T.SM_Tenant_OtherNames WHEN 'COMMITTEE' THEN T.SM_Committee_OtherNames END, 
      @BusinessName = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_BusinessName WHEN 'OTHER1' THEN T.SM_Other1_BusinessName WHEN 'OTHER2' THEN T.SM_Other2_BusinessName WHEN 'AGENT' THEN T.SM_Agent_BusinessName WHEN 'TENANT' THEN T.SM_Tenant_BusinessName WHEN 'COMMITTEE' THEN T.SM_Committee_BusinessName END, 
      @Title = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Title WHEN 'OTHER1' THEN T.SM_Other1_Title WHEN 'OTHER2' THEN T.SM_Other2_Title WHEN 'AGENT' THEN T.SM_Agent_Title WHEN 'TENANT' THEN T.SM_Tenant_Title WHEN 'COMMITTEE' THEN T.SM_Committee_Title  END, 
      @Email1 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Email1 WHEN 'OTHER1' THEN T.SM_Other1_Email1 WHEN 'OTHER2' THEN T.SM_Other2_Email1 WHEN 'AGENT' THEN T.SM_Agent_Email1 WHEN 'TENANT' THEN T.SM_Tenant_Email1 WHEN 'COMMITTEE' THEN T.SM_Committee_Email1 END , 
      @Email2 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Email2 WHEN 'OTHER1' THEN T.SM_Other1_Email2 WHEN 'OTHER2' THEN T.SM_Other2_Email2 WHEN 'AGENT' THEN T.SM_Agent_Email2 WHEN 'TENANT' THEN T.SM_Tenant_Email2 WHEN 'COMMITTEE' THEN T.SM_Committee_Email2 END, 
      @Email3 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Email3 WHEN 'OTHER1' THEN T.SM_Other1_Email3 WHEN 'OTHER2' THEN T.SM_Other2_Email3 WHEN 'AGENT' THEN T.SM_Agent_Email3 WHEN 'TENANT' THEN T.SM_Tenant_Email3 WHEN 'COMMITTEE' THEN T.SM_Committee_Email3 END, 
      @Mobile = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Mobile1 WHEN 'OTHER1' THEN T.SM_Other1_Mobile1 WHEN 'OTHER2' THEN T.SM_Other2_Mobile1 WHEN 'AGENT' THEN T.SM_Agent_Mobile1 WHEN 'TENANT' THEN T.SM_Tenant_Mobile1 WHEN 'COMMITTEE' THEN T.SM_Committee_Mobile1 END, 
      @Mobile_Notes = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Mobile1_Note WHEN 'OTHER1' THEN T.SM_Other1_Mobile1_Note WHEN 'OTHER2' THEN T.SM_Other2_Mobile1_Note WHEN 'AGENT' THEN T.SM_Agent_Mobile1_Note WHEN 'TENANT' THEN T.SM_Tenant_Mobile1_Note   WHEN 'COMMITTEE' THEN T.SM_Committee_Mobile1_Note END, 
      @Mobile2 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Mobile2 WHEN 'OTHER1' THEN T.SM_Other1_Mobile2 WHEN 'OTHER2' THEN T.SM_Other2_Mobile2 WHEN 'AGENT' THEN T.SM_Agent_Mobile2 WHEN 'TENANT' THEN T.SM_Tenant_Mobile2 WHEN 'COMMITTEE' THEN T.SM_Committee_Mobile2 END, 
      @Mobile2_Notes = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Mobile2_Note WHEN 'OTHER1' THEN T.SM_Other1_Mobile2_Note WHEN 'OTHER2' THEN T.SM_Other2_Mobile2_Note WHEN 'AGENT' THEN T.SM_Agent_Mobile2_Note WHEN 'TENANT' THEN T.SM_Tenant_Mobile2_Note WHEN 'COMMITTEE' THEN T.SM_Committee_Mobile2_Note  END, 
      
      @LandLine1 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_LandLine1 WHEN 'OTHER1' THEN T.SM_Other1_LandLine1 WHEN 'OTHER2' THEN T.SM_Other2_LandLine1 WHEN 'AGENT' THEN T.SM_Agent_LandLine1 WHEN 'TENANT' THEN T.SM_Tenant_LandLine1  WHEN 'COMMITTEE' THEN T.SM_Committee_LandLine1 END, 
      @LandLine1_Notes = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_LandLine1_Note WHEN 'OTHER1' THEN T.SM_Other1_LandLine1_Note WHEN 'OTHER2' THEN T.SM_Other2_LandLine1_Note WHEN 'AGENT' THEN T.SM_Agent_LandLine1_Note WHEN 'TENANT' THEN T.SM_Tenant_LandLine1_Note   WHEN 'COMMITTEE' THEN T.SM_Committee_LandLine1_Note END, 
      @LandLine2 = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_LandLine2 WHEN 'OTHER1' THEN T.SM_Other1_LandLine2 WHEN 'OTHER2' THEN T.SM_Other2_LandLine2 WHEN 'AGENT' THEN T.SM_Agent_LandLine2  WHEN 'TENANT' THEN T.SM_Tenant_LandLine2  WHEN 'COMMITTEE' THEN T.SM_Committee_LandLine2 END, 
      @LandLine2_Notes = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_LandLine2_Note WHEN 'OTHER1' THEN T.SM_Other1_LandLine2_Note WHEN 'OTHER2' THEN T.SM_Other2_LandLine2_Note WHEN 'AGENT' THEN T.SM_Agent_LandLine2_Note WHEN 'TENANT' THEN T.SM_Tenant_LandLine2_Note  WHEN 'COMMITTEE' THEN T.SM_Committee_LandLine2_Note END, 
      @Fax = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Fax WHEN 'OTHER1' THEN T.SM_Other1_Fax WHEN 'OTHER2' THEN T.SM_Other2_Fax WHEN 'AGENT' THEN T.SM_Agent_Fax WHEN 'TENANT' THEN T.SM_Tenant_Fax  WHEN 'COMMITTEE' THEN T.SM_Committee_Fax END, 
      @Country = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_Country WHEN 'OTHER1' THEN T.SM_Other1_Country WHEN 'OTHER2' THEN T.SM_Other2_Country WHEN 'AGENT' THEN T.SM_Agent_Country WHEN 'TENANT' THEN T.SM_Tenant_Country WHEN 'COMMITTEE' THEN T.SM_Committee_Country END, 
      @PoBox = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_PoBox WHEN 'OTHER1' THEN T.SM_Other1_PoBox WHEN 'OTHER2' THEN T.SM_Other2_PoBox WHEN 'AGENT' THEN T.SM_Agent_PoBox WHEN 'TENANT' THEN T.SM_Tenant_PoBox WHEN 'COMMITTEE' THEN T.SM_Committee_PoBox  END
      ,@IsbusinessContact = CASE @ContactType WHEN 'OWNER' THEN T.SM_Owner_IsBusinessContact WHEN 'OTHER1' THEN T.SM_Other1_IsBusinessContact WHEN 'OTHER2' THEN T.SM_Other2_IsBusinessContact WHEN 'AGENT' THEN T.SM_Agent_IsBusinessContact WHEN 'TENANT' THEN T.SM_Tenant_IsBusinessContact  WHEN 'COMMITTEE' THEN T.SM_Committee_IsBusinessContact END

      --select SM_Owner_NameOnTitle,  *
      FROM 
       [dbo].[T_SNG_IMPORT_MasterData] T
      WHERE ID = @ID
      --T.SM_OwnerContactID = @SM_ContactID;

      --SELECT  @BuildingName  , @StreetNo , @StreetName , @Suburb , 
      --@StateCode , @PostCode ,
      --@ContactName , @FirstName ,  @OtherNames , @Title , @Email1 ,@Email2 ,@Email3 , @Mobile , 
      --@LandLine2 ,  @LandLine1 , @Fax , @Country , @PoBox 

      DECLARE @IsAddressAvailable BIt = 0

       IF @ContactType = 'TENANT'
       BEGIN
       select @AddressID = SNG_LotAddressID
       FROM [dbo].[T_SNG_IMPORT_MasterData] T
       WHERE ID = @ID
       END
       IF(@AddressID IS NULL)
       BEGIN
       IF (TRIM(ISNULL(@StreetNo,'')) + TRIM(ISNULL(@StreetName,'')) + TRIM(ISNULL(@Suburb,'')) + TRIM(ISNULL(@StateCode,'')) + TRIM(ISNULL(@PostCode,''))) = ''
       BEGIN
        --SET @StreetNo = 'NA'
        --SET @StreetName = 'NA-'+ LEFT(CONVERT(varchar(36),NEWID()),8)
        --SET @Suburb = 'NA'
        --SET @StateCode = NULL
        --SET @PostCode = NULL
        SET @IsAddressAvailable = 0
       END
       ELSE
       BEGIN
        SET @IsAddressAvailable = 1
       END
      END

       IF(ISNULL(@PoBox,'') <> '')
       BEGIN
       SET @AusType  = NULL
       SET @PoboxType = 'POX'
       SET @PoBox = @PoBox
       SET @PostCodePo = @PostCode
       SET @SuburbPo = @Suburb
       SET @StateCodePo = @StateCode
       SET @StreetNo = NULL
       SET @StreetName = NULL
       SET @Suburb = NULL
       SET @StateCode = NULL
       SET @PostCode = NULL
       END

       SELECT @CountryCode = CountryCode FROM T_SNG_Countries 
      WHERE CountryName = @Country

        IF ((@Country <> '' AND @Country NOT IN('Australia','Aus')) --( @Country <>'Australia' OR @Country <>'Aus'))
       OR (iSNULL(@StateCode,'') not in ('ACT', 'NSW', 'NT', 'QLD', 'SA', 'TAS', 'VIC', 'WA') and @StreetName is not NULL))
       BEGIN 
       print('IN-INA')
        SET @Line1 = @StreetNo
        SET  @Line2 = @StreetName 
        SET  @Line3 = @Suburb
        SET  @Line4 = @StateCode
        SET  @Line5 = @PostCode
        SET @AusType  = NULL
        SET @PoboxType = NULL
        SET @InterAdds = 'INA'
        SET @PoBox = NULL
        SET @PostCodePo = NULL
        SET @SuburbPo = NULL
        SET @StateCodePo = NULL
        SET @StreetNo = NULL
        SET @StreetName = NULL
        SET @Suburb = NULL
        SET @StateCode = NULL
        SET @PostCode = NULL
        
        --SET @CountryCode = @CompanyCode
       END

   

   if @ContactType <> 'TENANT' AND @IsAddressAvailable = 1
   BEGIN
     EXEC [dbo].[P_SNG_PROPERTY_AddressInsertConfirmation]
         @BuildingName,
         @UnitNumber,
         @StreetNo,
         @StreetName,
         @PostCode,
         @Suburb,
         @StateCode,
         @PoBox,
         @CountryCode,
         @AddressId,
         @Line1,
         @Line2,
         @Line3,
         @Line4,
         @Line5,
         @AusType,
         @PoboxType,
         @InterAdds,
         @PostCodePo,
         @SuburbPo,
         @StateCodePo,
         @UserID,
         @CompanyCode,
         @latitude,
         @longitude,    
         @placeurl,
         --@ComType,
         --@Lot_ID,
         @AddressIdOut OUT,
         @ReturnMessage OUT

         SET @AddressId = @AddressIdOut
     END

      DECLARE @IsOwerrOccupied varchar(5) = NULL

      select @IsOwerrOccupied = SM_Lot_OwnerOccupied
       FROM [dbo].[T_SNG_IMPORT_MasterData] T
       WHERE ID = @ID

       IF @ContactType <> 'TENANT' AND @IsAddressAvailable = 0 AND @IsOwerrOccupied = 'Y'
       BEGIN
       select @AddressID = SNG_LotAddressID
       FROM [dbo].[T_SNG_IMPORT_MasterData] T
       WHERE ID = @ID
       END  
   
  

      SELECT @ContactId = ContactID 
      FROM T_SNG_Contacts WHERE CompanyCode = @CompanyCode AND AddressID = @AddressID AND ISNULL(ContactName,'') = ISNULL(@ContactName,'') AND ISNULL(Email1,'') = ISNULL(@Email1,'') AND (ISNULL(Mobile,'') = ISNULL(@Mobile,'') OR ISNULL(LandLine1,'') = ISNULL(@LandLine1,''))

      EXEC [dbo].[P_SNG_PROPERTY_ContactInsertConfirmation] 
        @FirstName,
        @MiddleName,
        @LastName,
        @ContactName,
        @AddressID,
        @Mobile,
        @Mobile_Notes,
        @Mobile2,
        @Mobile2_Notes,
        @LandLine1,
        @LandLine1_Notes,
        @LandLine2,
        @LandLine2_Notes,    
        @Email1,
        @Email2,
        @Email3,       
        @Fax,
        @Title,
        @BusinessName,
        @ChangeRequestFiles,
          @ComType,
          @LotGUID,
        @ContactId,
        @SNG_UserID,
        @CompanyCode,
        @IsbusinessContact,
        @ContactIdOut out,
        @Response out

   SET @OUT_SNG_ContactID = @ContactIdOut;


   END --END CREATE LEVY CONTACT

 

END












