@isTest
private class ItemDonorImporterTest {

    @isTest
    static void testImportAndTriggerProcessing() {
        // 1. Setup Test Campaign
        Campaign testCampaign = new Campaign(
            Name = 'Annual Charity Gala 2026',
            IsActive = true
        );
        insert testCampaign;

        // 2. Setup Existing Contact to test Contact Matching
        Contact existingContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '111-222-3333'
        );
        insert existingContact;

        // 3. Prepare Staging Records for import
        List<Item_Donor__c> stagedRecords = new List<Item_Donor__c>();
        
        // Record 1: Matches existing contact John Doe
        stagedRecords.add(new Item_Donor__c(
            Donor_Name__c = 'John Doe',
            Donor_Email__c = 'john.doe@example.com',
            Donor_Phone__c = '111-222-3333',
            Description__c = 'Autographed Sports Memorabilia',
            Estimated_Amount__c = 500.00,
            Realized_Amount__c = 450.00,
            Close_Date__c = Date.today(),
            Primary_Campaign_Source__c = testCampaign.Id,
            Charitable_Fund__c = 'General Fund',
            Status__c = 'Staged'
        ));

        // Record 2: New Contact Jane Smith (needs auto-creation)
        stagedRecords.add(new Item_Donor__c(
            Donor_Name__c = 'Jane Smith',
            Donor_Email__c = 'jane.smith@example.com',
            Donor_Phone__c = '999-888-7777',
            Description__c = 'Voucher for 2 nights at Luxury Resort',
            Estimated_Amount__c = 1000.00,
            Realized_Amount__c = 1200.00,
            Close_Date__c = Date.today(),
            Primary_Campaign_Source__c = testCampaign.Id,
            Charitable_Fund__c = 'Building Fund',
            Status__c = 'Staged'
        ));

        // Record 3: Edge case - Name without space
        stagedRecords.add(new Item_Donor__c(
            Donor_Name__c = 'BobCorp',
            Donor_Email__c = 'info@bobcorp.com',
            Donor_Phone__c = '555-555-5555',
            Description__c = 'Company Service Package',
            Estimated_Amount__c = 200.00,
            Realized_Amount__c = 200.00,
            Close_Date__c = Date.today(),
            Primary_Campaign_Source__c = testCampaign.Id,
            Charitable_Fund__c = 'General Fund',
            Status__c = 'Staged'
        ));

        Test.startTest();
        // Call LWC Controller
        Integer importCount = ItemDonorImporterController.importRecords(stagedRecords);
        Test.stopTest();

        // 4. Assert Staging record insertion count
        System.assertEquals(3, importCount, 'All 3 records should have been imported');

        // 5. Verify Contacts after processing
        // John Doe shouldn't be duplicated (only 1 John Doe should exist)
        List<Contact> johnContacts = [SELECT Id FROM Contact WHERE Email = 'john.doe@example.com'];
        System.assertEquals(1, johnContacts.size(), 'John Doe contact should not be duplicated');

        // Jane Smith should be created
        List<Contact> janeContacts = [SELECT Id, FirstName, LastName, Phone FROM Contact WHERE Email = 'jane.smith@example.com'];
        System.assertEquals(1, janeContacts.size(), 'Jane Smith contact should have been created');
        System.assertEquals('Jane', janeContacts[0].FirstName);
        System.assertEquals('Smith', janeContacts[0].LastName);
        System.assertEquals('999-888-7777', janeContacts[0].Phone);

        // BobCorp contact check
        List<Contact> bobContacts = [SELECT Id, FirstName, LastName FROM Contact WHERE Email = 'info@bobcorp.com'];
        System.assertEquals(1, bobContacts.size(), 'BobCorp contact should have been created');
        System.assertEquals('BobCorp', bobContacts[0].LastName, 'Single names should default to LastName');

        // 6. Verify Opportunities created
        List<Opportunity> createdOpps = [SELECT Id, Name, Amount, CloseDate, CampaignId, Charitable_Fund__c, Description, StageName, npsp__Acknowledgment_Status__c, npsp__Primary_Contact__c, Item_Donor__c FROM Opportunity WHERE CampaignId = :testCampaign.Id];
        System.assertEquals(3, createdOpps.size(), '3 Opportunities should have been created');

        // Map opportunities by primary contact to check specific values
        Map<Id, Opportunity> contactToOppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : createdOpps) {
            contactToOppMap.put(opp.npsp__Primary_Contact__c, opp);
        }

        // Verify John Doe's Opportunity
        Opportunity johnOpp = contactToOppMap.get(existingContact.Id);
        System.assertNotEquals(null, johnOpp, 'Opportunity for John Doe should exist');
        System.assertEquals('John Doe - In-Kind Gift', johnOpp.Name);
        System.assertEquals(450.00, johnOpp.Amount);
        System.assertEquals(Date.today(), johnOpp.CloseDate);
        System.assertEquals('In-Kind Received', johnOpp.StageName);
        System.assertEquals('To Be Acknowledged', johnOpp.npsp__Acknowledgment_Status__c);
        System.assertEquals('General Fund', johnOpp.Charitable_Fund__c);
        System.assertEquals('Autographed Sports Memorabilia', johnOpp.Description);
        System.assertNotEquals(null, johnOpp.Item_Donor__c, 'Opportunity should link to Item Donor');

        // Verify Jane Smith's Opportunity
        Opportunity janeOpp = contactToOppMap.get(janeContacts[0].Id);
        System.assertNotEquals(null, janeOpp, 'Opportunity for Jane Smith should exist');
        System.assertEquals('Jane Smith - In-Kind Gift', janeOpp.Name);
        System.assertEquals(1200.00, janeOpp.Amount);
        System.assertEquals('Building Fund', janeOpp.Charitable_Fund__c);

        // Verify staging records updated successfully
        List<Item_Donor__c> processedStaging = [SELECT Id, Status__c, Error_Message__c, Primary_Contact__c FROM Item_Donor__c];
        for (Item_Donor__c staging : processedStaging) {
            System.assertEquals('Processed', staging.Status__c, 'All staging records should be processed');
            System.assert(String.isBlank(staging.Error_Message__c), 'Error message should be blank/null');
            System.assertNotEquals(null, staging.Primary_Contact__c, 'Primary contact lookup must be populated');
        }
    }

    @isTest
    static void testImportRecordWithoutEmail() {
        Campaign testCampaign = new Campaign(
            Name = 'General Fund Campaign',
            IsActive = true
        );
        insert testCampaign;

        // Existing contact without email, matching by name
        Contact existingContact = new Contact(
            FirstName = 'Salt',
            LastName = 'of the Earth'
        );
        insert existingContact;

        List<Item_Donor__c> stagedRecords = new List<Item_Donor__c>();
        
        // Record 1: Matches name "Salt of the Earth" (no email)
        stagedRecords.add(new Item_Donor__c(
            Donor_Name__c = 'Salt of the Earth',
            Donor_Email__c = null,
            Donor_Phone__c = '555-0001',
            Description__c = 'Salt Box Item',
            Estimated_Amount__c = 100.00,
            Realized_Amount__c = 100.00,
            Close_Date__c = Date.today(),
            Primary_Campaign_Source__c = testCampaign.Id,
            Status__c = 'Staged'
        ));

        // Record 2: Completely new contact (no email)
        stagedRecords.add(new Item_Donor__c(
            Donor_Name__c = 'Camp Tosebo',
            Donor_Email__c = null,
            Donor_Phone__c = '555-0002',
            Description__c = 'Camp Ground Rental',
            Estimated_Amount__c = 500.00,
            Realized_Amount__c = 500.00,
            Close_Date__c = Date.today(),
            Primary_Campaign_Source__c = testCampaign.Id,
            Status__c = 'Staged'
        ));

        Test.startTest();
        ItemDonorImporterController.importRecords(stagedRecords);
        Test.stopTest();

        // Verify Contact without email matched or created
        List<Contact> saltContacts = [SELECT Id FROM Contact WHERE Name = 'Salt of the Earth'];
        System.assertEquals(1, saltContacts.size(), 'Should match the existing contact and not duplicate it');

        List<Contact> campContacts = [SELECT Id, FirstName, LastName FROM Contact WHERE Name = 'Camp Tosebo'];
        System.assertEquals(1, campContacts.size(), 'Should create new contact for Camp Tosebo');
        System.assertEquals('Camp', campContacts[0].FirstName);
        System.assertEquals('Tosebo', campContacts[0].LastName);

        // Verify Opportunities
        List<Opportunity> opportunities = [SELECT Id, Name, npsp__Primary_Contact__c FROM Opportunity WHERE CampaignId = :testCampaign.Id];
        System.assertEquals(2, opportunities.size(), '2 Opportunities should be created');
    }

    @isTest
    static void testEmptyImportException() {
        try {
            ItemDonorImporterController.importRecords(new List<Item_Donor__c>());
            System.assert(false, 'Should have thrown an exception on empty list');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No records to import') || e.getMessage().contains('Script-thrown exception'), 'Exception message should indicate empty records list');
        }
    }
}