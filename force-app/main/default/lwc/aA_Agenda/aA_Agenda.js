import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCustomerNameFromSession from '@salesforce/apex/AA_PublicAppointmentController.getCustomerNameFromSession';
import createAppointment from '@salesforce/apex/AA_PublicAppointmentController.createAppointment';

export default class AaClientPicker extends LightningElement {
    sessionId;
    customerName;
    @track daysWithSlots = [];
    minDate = new Date().toISOString().split('T')[0]; // Hoy

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.sessionId = currentPageReference.state.sessionId;
        }
    }

    @wire(getCustomerNameFromSession, { sessionId: '$sessionId' })
    wiredCustomer({ error, data }) {
        if (data) this.customerName = data;
    }

    handleDateChange(event) {
        const selectedDate = event.target.value;
        this.generateHardcodedSlots(selectedDate);
    }

    generateHardcodedSlots(startDate) {
        // Simulamos la lógica de "Este día + 3 próximos"
        let baseDate = new Date(startDate);
        let mockDays = [];

        for (let i = 0; i < 4; i++) {
            let currentDate = new Date(baseDate);
            currentDate.setDate(baseDate.getDate() + i);
            
            mockDays.push({
                dateLabel: currentDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' }),
                slots: [
                    { id: `slot-${i}-1`, time: '09:00' },
                    { id: `slot-${i}-2`, time: '10:30' },
                    { id: `slot-${i}-3`, time: '14:00' },
                    { id: `slot-${i}-4`, time: '16:00' }
                ]
            });
        }
        this.daysWithSlots = mockDays;
    }

    handleSlotSelection(event) {
        const slotId = event.target.dataset.id;
        alert('Has seleccionado el slot: ' + slotId + '. Próximo paso: Guardar en Salesforce.');
    }

    @track isFinished = false;

    async handleSubmit() {
        this.loadingSlots = true; // Reutilizamos el spinner
        try {
            await createAppointment({ 
                sessionId: this.sessionId, 
                slotId: this.selectedSlotId 
            });
            
            // Si todo sale bien, mostramos pantalla de éxito
            this.isFinished = true;
        } catch (error) {
            console.error('Error al confirmar', error);
            // Aquí podrías mostrar un toast o mensaje de error
        } finally {
            this.loadingSlots = false;
        }
    }
}