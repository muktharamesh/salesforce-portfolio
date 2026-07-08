import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import importRecords from '@salesforce/apex/ItemDonorImporterController.importRecords';

export default class ItemDonorImporter extends LightningElement {
    @api recordId; // Captures Campaign Id if on Campaign page
    @track campaignId;
    @track closeDate;
    @track charitableFund;
    @track fileName = '';
    @track fileData;
    @track isLoading = false;

    connectedCallback() {
        if (this.recordId) {
            this.campaignId = this.recordId;
        }
    }

    handleCampaignChange(event) {
        const val = event.detail.value;
        this.campaignId = Array.isArray(val) ? (val.length > 0 ? val[0] : null) : val;
    }

    handleCloseDateChange(event) {
        this.closeDate = event.target.value;
    }

    handleCharitableFundChange(event) {
        this.charitableFund = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.fileName = file.name;
            const reader = new FileReader();
            reader.onload = () => {
                this.fileData = reader.result;
            };
            reader.readAsText(file);
        }
    }

    handleReset() {
        this.campaignId = this.recordId ? this.recordId : null;
        this.closeDate = '';
        this.charitableFund = '';
        this.fileName = '';
        this.fileData = null;
    }

    get isSubmitDisabled() {
        return !this.campaignId || !this.closeDate || !this.fileData || this.isLoading;
    }

    handleImport() {
        if (!this.campaignId || !this.closeDate || !this.fileData) {
            this.showToast('Error', 'Please fill in all required fields and upload a CSV file.', 'error');
            return;
        }

        const selectedCampaignId = Array.isArray(this.campaignId) 
            ? (this.campaignId.length > 0 ? this.campaignId[0] : null) 
            : this.campaignId;

        this.isLoading = true;
        try {
            const parsedData = this.parseCSV(this.fileData);
            if (parsedData.length < 2) {
                throw new Error('CSV file is empty or only contains headers.');
            }

            const headers = parsedData[0].map(h => h.trim().toLowerCase());
            
            // Map indexes
            const descIndex = headers.indexOf('item name');
            const estAmtIndex = headers.indexOf('estimated amount');
            const donorNameIndex = headers.indexOf('donor name');
            const realizedAmtIndex = headers.indexOf('realized amount');
            const emailIndex = headers.indexOf('donor email');
            const phoneIndex = headers.indexOf('donor phone');

            if (donorNameIndex === -1 || emailIndex === -1) {
                throw new Error('CSV must contain "Donor Name" and "Donor Email" columns.');
            }

            const stagingRecords = [];
            for (let i = 1; i < parsedData.length; i++) {
                const row = parsedData[i];
                if (row.length < headers.length || !row[donorNameIndex]) {
                    continue; // Skip empty rows
                }

                const estAmt = estAmtIndex !== -1 ? parseFloat(row[estAmtIndex].replace(/[^0-9.-]+/g, '')) : null;
                const realAmt = realizedAmtIndex !== -1 ? parseFloat(row[realizedAmtIndex].replace(/[^0-9.-]+/g, '')) : null;

                stagingRecords.push({
                    sobjectType: 'Item_Donor__c',
                    Donor_Name__c: row[donorNameIndex] ? row[donorNameIndex].trim() : '',
                    Donor_Email__c: row[emailIndex] ? row[emailIndex].trim() : '',
                    Donor_Phone__c: phoneIndex !== -1 && row[phoneIndex] ? row[phoneIndex].trim() : '',
                    Description__c: descIndex !== -1 && row[descIndex] ? row[descIndex].trim() : '',
                    Estimated_Amount__c: isNaN(estAmt) ? null : estAmt,
                    Realized_Amount__c: isNaN(realAmt) ? null : realAmt,
                    Close_Date__c: this.closeDate,
                    Primary_Campaign_Source__c: selectedCampaignId,
                    Charitable_Fund__c: this.charitableFund ? this.charitableFund.trim() : '',
                    Status__c: 'Staged'
                });
            }

            if (stagingRecords.length === 0) {
                throw new Error('No valid records found to import.');
            }

            // Call Apex
            importRecords({ records: stagingRecords })
                .then(result => {
                    this.showToast('Success', `Successfully imported ${result} records into staging table! They are being processed now.`, 'success');
                    this.handleReset();
                })
                .catch(error => {
                    this.showToast('Import Error', error.body ? error.body.message : error.message, 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });

        } catch (e) {
            this.showToast('Parsing Error', e.message, 'error');
            this.isLoading = false;
        }
    }

    // Helper to parse CSV properly (handles values with commas enclosed in quotes)
    parseCSV(text) {
        let lines = [];
        let row = [""];
        let inQuotes = false;

        for (let i = 0; i < text.length; i++) {
            let c = text[i];
            let next = text[i + 1];
            if (c === '"') {
                if (inQuotes && next === '"') {
                    row[row.length - 1] += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c === ',' && !inQuotes) {
                row.push('');
            } else if ((c === '\r' || c === '\n') && !inQuotes) {
                if (c === '\r' && next === '\n') {
                    i++;
                }
                lines.push(row);
                row = [''];
            } else {
                row[row.length - 1] += c;
            }
        }
        if (row.length > 1 || row[0] !== '') {
            lines.push(row);
        }
        return lines;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}