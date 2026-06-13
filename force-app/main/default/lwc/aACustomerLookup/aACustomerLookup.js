import { LightningElement, track, api } from 'lwc';
import searchCustomers from '@salesforce/apex/AA_CustomerLookupController.searchCustomers';
import createCustomer from '@salesforce/apex/AA_CustomerLookupController.createCustomer';

export default class AACustomerLookup extends LightningElement {
    @api selectedCustomerId;
    @api selectedCustomerName;
    
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track showDropdown = false;
    @track isCreating = false;
    @track errorMsg = '';
    
    @track newFirstName = '';
    @track newLastName = '';
    @track newPhone = '';
    
    searchTimeout;
    
    get hasResults() {
        return this.searchResults && this.searchResults.length > 0;
    }
    
    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        this.errorMsg = '';
        
        if (this.searchTerm.length >= 3) {
            this.isSearching = true;
            this.showDropdown = true;
            
            // Debounce
            if (this.searchTimeout) {
                clearTimeout(this.searchTimeout);
            }
            
            this.searchTimeout = setTimeout(() => {
                this.executeSearch();
            }, 300);
        } else {
            this.searchResults = [];
            this.showDropdown = false;
        }
    }
    
    async executeSearch() {
        try {
            const results = await searchCustomers({ searchTerm: this.searchTerm });
            this.searchResults = results.map(item => {
                return {
                    id: item.Id,
                    name: (item.First_Name__c || '') + ' ' + (item.Last_Name__c || ''),
                    phone: item.Phone_Number__c ? item.Phone_Number__c : 'Sin celular'
                };
            });
        } catch (error) {
            console.error('Error buscando clientes', error);
            this.errorMsg = 'Error al buscar clientes.';
        } finally {
            this.isSearching = false;
        }
    }
    
    handleSelectCustomer(event) {
        const customerId = event.currentTarget.dataset.id;
        const customerName = event.currentTarget.dataset.name;
        
        this.selectCustomer(customerId, customerName);
    }
    
    selectCustomer(id, name) {
        this.selectedCustomerId = id;
        this.selectedCustomerName = name;
        this.searchTerm = name;
        this.showDropdown = false;
        
        // Dispatch event para el padre
        this.dispatchEvent(new CustomEvent('customerselect', {
            detail: {
                customerId: id,
                customerName: name
            }
        }));
    }
    
    handleClearSelection() {
        this.selectedCustomerId = null;
        this.selectedCustomerName = '';
        this.searchTerm = '';
        this.searchResults = [];
        this.dispatchEvent(new CustomEvent('customerselect', {
            detail: {
                customerId: null,
                customerName: ''
            }
        }));
    }
    
    handleOpenCreateForm() {
        this.isCreating = true;
        this.showDropdown = false;
    }
    
    handleCloseCreateForm() {
        this.isCreating = false;
        this.newFirstName = '';
        this.newLastName = '';
        this.newPhone = '';
        this.errorMsg = '';
    }
    
    handleNewFieldChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }
    
    async handleCreateCustomer() {
        if (!this.newFirstName || !this.newLastName) {
            this.errorMsg = 'Nombre y Apellido son obligatorios.';
            return;
        }
        
        try {
            this.isSearching = true;
            this.errorMsg = '';
            const newCust = await createCustomer({
                firstName: this.newFirstName,
                lastName: this.newLastName,
                phone: this.newPhone
            });
            
            this.handleCloseCreateForm();
            this.selectCustomer(newCust.Id, newCust.First_Name__c + ' ' + newCust.Last_Name__c);
            
        } catch (error) {
            console.error('Error creando cliente', error);
            this.errorMsg = error.body ? error.body.message : 'Error al crear el cliente.';
        } finally {
            this.isSearching = false;
        }
    }
    
    // Cerrar dropdown si hace click afuera (usando un blur simplificado o escuchando body en connectedCallback)
    handleBlur() {
        // Un pequeño delay para permitir el clic en los elementos del dropdown
        setTimeout(() => {
            if (!this.isCreating) {
                this.showDropdown = false;
            }
        }, 200);
    }
}
