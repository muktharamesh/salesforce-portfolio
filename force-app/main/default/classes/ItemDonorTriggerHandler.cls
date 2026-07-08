public with sharing class ItemDonorTriggerHandler {
    
    // Prevent recursion
    public static Boolean isExecuting = false;

    public static void handleAfterInsert(List<Item_Donor__c> newRecords) {
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        try {
            processStagingRecords(newRecords);
        } finally {
            isExecuting = false;
        }
    }

    public static void processStagingRecords(List<Item_Donor__c> records) {
        List<Item_Donor__c> stagedRecords = new List<Item_Donor__c>();
        Set<String> emails = new Set<String>();
        Set<String> names = new Set<String>();

        for (Item_Donor__c rec : records) {
            // Only process records that have at least a donor name or donor email
            if (rec.Status__c == 'Staged' && (String.isNotBlank(rec.Donor_Name__c) || String.isNotBlank(rec.Donor_Email__c))) {
                stagedRecords.add(rec);
                if (String.isNotBlank(rec.Donor_Email__c)) {
                    emails.add(rec.Donor_Email__c.trim().toLowerCase());
                }
                if (String.isNotBlank(rec.Donor_Name__c)) {
                    names.add(rec.Donor_Name__c.trim().toLowerCase());
                }
            }
        }

        if (stagedRecords.isEmpty()) {
            return;
        }

        // 1. Query existing Contacts by Email or by Name (if email is null)
        Map<String, Contact> emailToContactMap = new Map<String, Contact>();
        Map<String, Contact> nameToContactMap = new Map<String, Contact>();
        
        for (Contact c : [SELECT Id, Email, Name, FirstName, LastName, Phone FROM Contact WHERE (Email IN :emails AND Email != null) OR (Name IN :names AND Email = null)]) {
            if (c.Email != null) {
                emailToContactMap.put(c.Email.toLowerCase(), c);
            } else if (c.Name != null) {
                nameToContactMap.put(c.Name.toLowerCase(), c);
            }
        }

        // 2. Identify missing Contacts and prepare for insertion
        Map<String, Contact> contactsToInsertMap = new Map<String, Contact>();
        for (Item_Donor__c rec : stagedRecords) {
            String emailKey = String.isNotBlank(rec.Donor_Email__c) ? rec.Donor_Email__c.trim().toLowerCase() : null;
            String nameKey = String.isNotBlank(rec.Donor_Name__c) ? rec.Donor_Name__c.trim().toLowerCase() : null;
            
            Boolean hasExistingContact = false;
            if (emailKey != null && emailToContactMap.containsKey(emailKey)) {
                hasExistingContact = true;
            } else if (emailKey == null && nameKey != null && nameToContactMap.containsKey(nameKey)) {
                hasExistingContact = true;
            }
            
            if (!hasExistingContact) {
                String dedupKey = emailKey != null ? emailKey : nameKey;
                if (dedupKey != null && !contactsToInsertMap.containsKey(dedupKey)) {
                    Contact newContact = new Contact();
                    if (emailKey != null) {
                        newContact.Email = rec.Donor_Email__c.trim();
                    }
                    newContact.Phone = rec.Donor_Phone__c;
                    
                    // Parse Name
                    String fullName = rec.Donor_Name__c != null ? rec.Donor_Name__c.trim() : '';
                    if (String.isBlank(fullName)) {
                        newContact.LastName = 'Item Donor';
                    } else if (fullName.contains(' ')) {
                        Integer firstSpaceIdx = fullName.indexOf(' ');
                        newContact.FirstName = fullName.substring(0, firstSpaceIdx);
                        newContact.LastName = fullName.substring(firstSpaceIdx + 1).trim();
                        if (String.isBlank(newContact.LastName)) {
                            newContact.LastName = 'Donor';
                        }
                    } else {
                        newContact.LastName = fullName;
                    }
                    contactsToInsertMap.put(dedupKey, newContact);
                }
            }
        }

        // Insert new Contacts if any
        if (!contactsToInsertMap.isEmpty()) {
            insert contactsToInsertMap.values();
            // Add new contacts to mapping maps
            for (String key : contactsToInsertMap.keySet()) {
                Contact c = contactsToInsertMap.get(key);
                if (c.Email != null) {
                    emailToContactMap.put(c.Email.toLowerCase(), c);
                } else {
                    nameToContactMap.put(key, c);
                }
            }
        }

        // 3. Retrieve "In-Kind Gift" Opportunity Record Type ID
        Id inKindRecTypeId;
        try {
            inKindRecTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('In-Kind Gift').getRecordTypeId();
        } catch (Exception e) {
            System.debug('Warning: In-Kind Gift record type not found. Falling back to default.');
        }

        // 4. Build Opportunities
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        List<Item_Donor__c> mappedStagingRecords = new List<Item_Donor__c>();

        for (Item_Donor__c rec : stagedRecords) {
            String emailKey = String.isNotBlank(rec.Donor_Email__c) ? rec.Donor_Email__c.trim().toLowerCase() : null;
            String nameKey = String.isNotBlank(rec.Donor_Name__c) ? rec.Donor_Name__c.trim().toLowerCase() : null;
            
            Contact matchedContact = null;
            if (emailKey != null) {
                matchedContact = emailToContactMap.get(emailKey);
            } else if (nameKey != null) {
                matchedContact = nameToContactMap.get(nameKey);
            }

            Opportunity opp = new Opportunity();
            String donorName = rec.Donor_Name__c != null ? rec.Donor_Name__c.trim() : 'Donor';
            opp.Name = donorName + ' - In-Kind Gift';
            
            if (inKindRecTypeId != null) {
                opp.RecordTypeId = inKindRecTypeId;
            }
            
            opp.Amount = rec.Realized_Amount__c;
            opp.Description = rec.Description__c;
            opp.CloseDate = rec.Close_Date__c;
            opp.CampaignId = rec.Primary_Campaign_Source__c;
            opp.Charitable_Fund__c = rec.Charitable_Fund__c;
            opp.StageName = 'In-Kind Received';
            opp.npsp__Acknowledgment_Status__c = 'To Be Acknowledged';
            
            if (matchedContact != null) {
                opp.npsp__Primary_Contact__c = matchedContact.Id;
            }

            opp.Item_Donor__c = rec.Id;

            opportunitiesToInsert.add(opp);
            mappedStagingRecords.add(rec);
        }

        // 5. Insert Opportunities using Database.insert for partial success handling
        List<Item_Donor__c> stagingRecordsToUpdate = new List<Item_Donor__c>();
        if (!opportunitiesToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(opportunitiesToInsert, false);
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                Item_Donor__c origRec = mappedStagingRecords[i];
                
                String emailKey = String.isNotBlank(origRec.Donor_Email__c) ? origRec.Donor_Email__c.trim().toLowerCase() : null;
                String nameKey = String.isNotBlank(origRec.Donor_Name__c) ? origRec.Donor_Name__c.trim().toLowerCase() : null;
                
                Contact c = null;
                if (emailKey != null) {
                    c = emailToContactMap.get(emailKey);
                } else if (nameKey != null) {
                    c = nameToContactMap.get(nameKey);
                }

                Item_Donor__c updateRec = new Item_Donor__c(Id = origRec.Id);
                if (c != null) {
                    updateRec.Primary_Contact__c = c.Id;
                }

                if (sr.isSuccess()) {
                    updateRec.Status__c = 'Processed';
                    updateRec.Error_Message__c = '';
                } else {
                    updateRec.Status__c = 'Failed';
                    List<String> errors = new List<String>();
                    for (Database.Error err : sr.getErrors()) {
                        errors.add(err.getStatusCode() + ': ' + err.getMessage());
                    }
                    updateRec.Error_Message__c = String.join(errors, '\n');
                }
                stagingRecordsToUpdate.add(updateRec);
            }
        }

        if (!stagingRecordsToUpdate.isEmpty()) {
            update stagingRecordsToUpdate;
        }
    }
}