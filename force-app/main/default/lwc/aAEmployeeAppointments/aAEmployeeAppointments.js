import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmployees from '@salesforce/apex/AA_EmployeeAppointmentsCtrl.getEmployees';
import getPendingAppointments from '@salesforce/apex/AA_EmployeeAppointmentsCtrl.getPendingAppointments';
import saveAppointmentDetails from '@salesforce/apex/AA_EmployeeAppointmentsCtrl.saveAppointmentDetails';

export default class AAEmployeeAppointments extends LightningElement {
    @track employeeOptions = [];
    @track selectedEmployeeId;
    @track selectedDate = new Date();
    @track appointments = [];
    @track isLoading = false;
    
    @track isModalOpen = false;
    @track selectedAppointment = null;
    @track editedData = {};

    paymentMethodOptions = [
        { label: 'Efectivo', value: 'Efectivo' },
        { label: 'Transferencia', value: 'Transferencia' },
        { label: 'Mercado Pago', value: 'Mercado Pago' },
        { label: 'Decido en el Momento', value: 'Decido en el Momento' }
    ];

    connectedCallback() {
        this.fetchEmployees();
    }

    get formattedDate() {
        return this.selectedDate.toLocaleDateString('es-ES', { 
            weekday: 'short', 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }

    get hasAppointments() {
        return this.appointments && this.appointments.length > 0;
    }

    fetchEmployees() {
        this.isLoading = true;
        getEmployees()
            .then(result => {
                this.employeeOptions = result.map(emp => ({
                    label: `${emp.First_Name__c} ${emp.Last_Name__c}`,
                    value: emp.Id
                }));
                if (this.employeeOptions.length > 0) {
                    this.selectedEmployeeId = this.employeeOptions[0].value;
                    this.fetchAppointments();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error cargando empleados', 'error');
                this.isLoading = false;
            });
    }

    fetchAppointments() {
        if (!this.selectedEmployeeId) return;
        
        this.isLoading = true;
        
        // Format date to YYYY-MM-DD
        const year = this.selectedDate.getFullYear();
        const month = String(this.selectedDate.getMonth() + 1).padStart(2, '0');
        const day = String(this.selectedDate.getDate()).padStart(2, '0');
        const dateString = `${year}-${month}-${day}`;

        getPendingAppointments({ employeeId: this.selectedEmployeeId, selectedDate: dateString })
            .then(result => {
                this.appointments = result.map(appt => {
                    let formattedTime = '';
                    if (appt.Start_Date_Time__c) {
                        const startDate = new Date(appt.Start_Date_Time__c);
                        formattedTime = startDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    }
                    let displayStatus = appt.Status__c;
                    if (displayStatus === 'Pending') {
                        displayStatus = 'Pendiente';
                    }
                    return {
                        ...appt,
                        formattedTime,
                        displayStatus
                    };
                });
            })
            .catch(error => {
                this.showToast('Error', 'Error cargando citas', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleEmployeeChange(event) {
        this.selectedEmployeeId = event.detail.value;
        this.fetchAppointments();
    }

    handlePrevDay() {
        const newDate = new Date(this.selectedDate);
        newDate.setDate(newDate.getDate() - 1);
        this.selectedDate = newDate;
        this.fetchAppointments();
    }

    handleNextDay() {
        const newDate = new Date(this.selectedDate);
        newDate.setDate(newDate.getDate() + 1);
        this.selectedDate = newDate;
        this.fetchAppointments();
    }

    handleToday() {
        this.selectedDate = new Date();
        this.fetchAppointments();
    }

    handleCardClick(event) {
        const apptId = event.currentTarget.dataset.id;
        this.selectedAppointment = this.appointments.find(a => a.Id === apptId);
        
        if (this.selectedAppointment) {
            // Initialize editedData with current values
            this.editedData = {
                customerIntComments: this.selectedAppointment.Customer__r.Internal_Comments__c || '',
                apptIntComments: this.selectedAppointment.Internal_Comments__c || '',
                paymentMethod: this.selectedAppointment.Payment_Method__c || '',
                paymentAmount: this.selectedAppointment.Payment_Amount__c || (this.selectedAppointment.Service__r ? this.selectedAppointment.Service__r.Price__c : null)
            };
            this.isModalOpen = true;
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedAppointment = null;
        this.editedData = {};
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.editedData[field] = event.target.value;
        
        if (field === 'paymentMethod' && event.target.value) {
            event.target.setCustomValidity('');
            event.target.reportValidity();
        }
    }

    handleSave() {
        this.saveData(false);
    }

    handleMarkAsDone() {
        if (!this.editedData.paymentMethod) {
            const combobox = this.template.querySelector('lightning-combobox[data-field="paymentMethod"]');
            if (combobox) {
                combobox.setCustomValidity('Debe especificar el método de pago.');
                combobox.reportValidity();
            }
            return;
        }
        this.saveData(true);
    }

    saveData(markAsDone) {
        this.isLoading = true;

        const apptData = {
            Id: this.selectedAppointment.Id,
            Payment_Method__c: this.editedData.paymentMethod,
            Payment_Amount__c: this.editedData.paymentAmount,
            Internal_Comments__c: this.editedData.apptIntComments
        };

        if (markAsDone) {
            apptData.Status__c = 'Done';
        }

        const custData = {
            Id: this.selectedAppointment.Customer__r.Id,
            Internal_Comments__c: this.editedData.customerIntComments
        };

        saveAppointmentDetails({ appointmentData: apptData, customerData: custData })
            .then(() => {
                this.showToast('Éxito', 'Los datos se guardaron correctamente', 'success');
                this.closeModal();
                this.fetchAppointments();
            })
            .catch(error => {
                this.showToast('Error', 'Hubo un error al guardar', 'error');
                console.error(error);
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
