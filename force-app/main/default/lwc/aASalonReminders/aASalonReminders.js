import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRemindersData from '@salesforce/apex/AA_SalonRemindersController.getRemindersData';
import confirmAppointment from '@salesforce/apex/AA_SalonAppointmentsController.confirmAppointment';
import markReminderAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markReminderAsSent';
import markBookConfirmationAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markBookConfirmationAsSent';
import markAsPaid from '@salesforce/apex/AA_SalonAppointmentsController.markAsPaid';

export default class AASalonReminders extends LightningElement {
    
    @track rawData = {
        confirmations: [],
        reminders: [],
        awaiting: [],
        pendingPayments: []
    };

    @track currentTab = 'confirmations';
    @track isModalOpen = false;
    @track previewMessage = '';
    
    @track tabs = [
        { id: 'confirmations', label: 'Confirmar Reserva', cssClass: 'tab-button tab-active' },
        { id: 'reminders', label: 'Recordatorios', cssClass: 'tab-button' },
        { id: 'awaiting', label: 'Aguardando Confirmación', cssClass: 'tab-button' },
        { id: 'pendingPayments', label: 'Cobros Pendientes', cssClass: 'tab-button' }
    ];

    wiredRemindersResult;

    @wire(getRemindersData)
    wiredData(result) {
        this.wiredRemindersResult = result;
        const { error, data } = result;
        if (data) {
            this.rawData = {
                confirmations: this.formatData(data.confirmations, 'Book_Confirmation_Message_Template__c'),
                reminders: this.formatData(data.reminders, 'Appointment_Reminder_Message_Template__c'),
                awaiting: this.formatData(data.awaiting, ''),
                pendingPayments: this.formatData(data.pendingPayments, 'Pending_Payment_Message_Template__c')
            };
            this.updateTabCounts();
        } else if (error) {
            console.error('Error loading reminders:', error);
        }
    }

    updateTabCounts() {
        this.tabs = this.tabs.map(tab => {
            const count = this.rawData && this.rawData[tab.id] ? this.rawData[tab.id].length : 0;
            return {
                ...tab,
                count: count,
                showBadge: count > 0
            };
        });
    }

    formatData(appointments, templateFieldName) {
        if (!appointments) return [];
        return appointments.map(appt => {
            const firstName = appt.Customer__r?.First_Name__c || '';
            const lastName = appt.Customer__r?.Last_Name__c || '';
            const fullName = `${firstName} ${lastName}`.trim() || 'Sin Nombre';
            const initial = firstName ? firstName.charAt(0).toUpperCase() : (lastName ? lastName.charAt(0).toUpperCase() : '-');
            
            let formattedDate = '';
            let apptDay = '';
            let apptHour = '';

            if (appt.Start_Date_Time__c) {
                const dt = new Date(appt.Start_Date_Time__c);
                formattedDate = dt.toLocaleString('es-UY', { 
                    day: '2-digit', month: '2-digit', year: 'numeric',
                    hour: '2-digit', minute: '2-digit', hour12: false
                }) + ' hs';
                apptDay = dt.toLocaleDateString('es-UY', { day: '2-digit', month: '2-digit', year: 'numeric' });
                apptHour = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: false });
            }

            const serviceName = appt.Service__r?.Display_Name__c || appt.Service__r?.Name || 'Servicio General';
            const address = appt.Service__r?.Business_Branch__r?.Address__c || '';
            const policy = appt.Service__r?.Business_Branch__r?.Business__r?.Cancellation_Policy__c || '';
            const duration = appt.Service__r?.Duration_Minutes__c ? appt.Service__r.Duration_Minutes__c + ' minutos' : 'No especificada';
            const amountText = appt.Payment_Amount__c ? '$' + appt.Payment_Amount__c : (appt.Service__r?.Price__c ? '$' + appt.Service__r.Price__c : 'A confirmar');
            
            let template = '';
            if (templateFieldName && appt.Service__r?.Business_Branch__r?.Business__r) {
                template = appt.Service__r.Business_Branch__r.Business__r[templateFieldName] || '';
            }
            let wpMessage = '';
            
            if (template) {
                wpMessage = template
                    .replace(/#customer_name#/g, firstName || fullName)
                    .replace(/#service_name#/g, serviceName)
                    .replace(/#appointment_day#/g, apptDay)
                    .replace(/#appointment_hour#/g, apptHour)
                    .replace(/#business_branch_address#/g, address)
                    .replace(/#cancellation_policy#/g, policy)
                    .replace(/#duration#/g, duration)
                    .replace(/#amount#/g, amountText);
            }

            return {
                Id: appt.Id,
                apptName: appt.Name,
                fullName: fullName,
                initial: initial,
                formattedDateTime: formattedDate,
                Phone_Number__c: appt.Customer__r?.Phone_Number__c || '-',
                serviceName: serviceName,
                amountText: amountText,
                whatsappMessage: wpMessage
            };
        });
    }

    get currentData() {
        return this.rawData[this.currentTab] || [];
    }

    get hasData() {
        return this.currentData.length > 0;
    }

    get isPendingPaymentsTab() {
        return this.currentTab === 'pendingPayments';
    }

    get isAwaitingTab() {
        return this.currentTab === 'awaiting';
    }

    handleTabChange(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.currentTab = selectedId;

        this.tabs = this.tabs.map(tab => {
            return {
                ...tab,
                cssClass: tab.id === selectedId ? 'tab-button tab-active' : 'tab-button'
            };
        });
    }

    async handleWhatsAppClick(event) {
        const phone = event.currentTarget.dataset.phone;
        const message = event.currentTarget.dataset.message;
        const appointmentId = event.currentTarget.dataset.id;
        
        if (phone && phone !== '-' && message) {
            const cleanPhone = phone.replace(/\D/g, '');
            window.open(`https://wa.me/${cleanPhone}?text=${encodeURIComponent(message)}`, '_blank');
            
            try {
                if (this.currentTab === 'reminders') {
                    await markReminderAsSent({ appointmentId: appointmentId });
                    await refreshApex(this.wiredRemindersResult);
                } else if (this.currentTab === 'confirmations') {
                    await markBookConfirmationAsSent({ appointmentId: appointmentId });
                    await refreshApex(this.wiredRemindersResult);
                }
            } catch (error) {
                console.error('Error executing backend logic for WhatsApp click:', error);
            }
        } else {
            console.log('No phone number or message template available.', { phone, message });
        }
    }

    async handleMarkAsPaid(event) {
        const appointmentId = event.currentTarget.dataset.id;
        try {
            await markAsPaid({ appointmentId: appointmentId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Cobro registrado correctamente',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredRemindersResult);
        } catch (error) {
            console.error('Error marking as paid:', error);
        }
    }

    async handleConfirmClick(event) {
        const appointmentId = event.currentTarget.dataset.id;
        try {
            await confirmAppointment({ appointmentId: appointmentId, internalComments: 'Confirmado internamente' });
            await refreshApex(this.wiredRemindersResult);
        } catch (error) {
            console.error('Error confirming appointment:', error);
        }
    }

    openPreview(event) {
        this.previewMessage = event.currentTarget.dataset.message;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.previewMessage = '';
    }

    async copyToClipboard() {
        if (navigator.clipboard && window.isSecureContext) {
            try {
                await navigator.clipboard.writeText(this.previewMessage);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Éxito',
                        message: 'Mensaje copiado al portapapeles',
                        variant: 'success'
                    })
                );
                this.closeModal();
            } catch (err) {
                console.error('Error copying to clipboard', err);
                this.fallbackCopyTextToClipboard();
            }
        } else {
            this.fallbackCopyTextToClipboard();
        }
    }

    fallbackCopyTextToClipboard() {
        const textArea = document.createElement("textarea");
        textArea.value = this.previewMessage;
        textArea.style.position = "fixed";
        textArea.style.left = "-999999px";
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
            document.execCommand('copy');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Mensaje copiado al portapapeles',
                    variant: 'success'
                })
            );
            this.closeModal();
        } catch (err) {
            console.error('Error fallback copy', err);
        }
        document.body.removeChild(textArea);
    }
}