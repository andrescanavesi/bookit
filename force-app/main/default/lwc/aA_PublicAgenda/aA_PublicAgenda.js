import { LightningElement, track, api } from 'lwc';

import getOrCreateCustomer from '@salesforce/apex/AA_PublicAgendaController.getOrCreateCustomer';
import getCategories from '@salesforce/apex/AA_PublicAgendaController.getCategories';
import getServices from '@salesforce/apex/AA_PublicAgendaController.getServices';
import getBusinessInfo from '@salesforce/apex/AA_PublicAgendaController.getBusinessInfo';
import updateCustomer from '@salesforce/apex/AA_PublicAgendaController.updateCustomer';
import getAvailableSlots from '@salesforce/apex/AA_PublicAgendaController.getAvailableSlots';
import saveAppointment from '@salesforce/apex/AA_PublicAgendaController.saveAppointment';
import getComboSlots from '@salesforce/apex/AA_PublicAgendaController.getComboSlots';
import saveComboAppointments from '@salesforce/apex/AA_PublicAgendaController.saveComboAppointments';
import getMisTurnos from '@salesforce/apex/AA_PublicAgendaController.getMisTurnos';
import cancelarAppointment from '@salesforce/apex/AA_PublicAgendaController.cancelarAppointment';
import confirmarAsistencia from '@salesforce/apex/AA_PublicAgendaController.confirmarAsistencia';
import recoordinarAppointment from '@salesforce/apex/AA_PublicAgendaController.recoordinarAppointment';

export default class AAPublicAgenda extends LightningElement {
    @api businessId

    // --- ESTADO GLOBAL ---
    currentScreen = 'welcome';
    reservaStep = 1;
    misTurnosStep = 1;

    @track businessInfo = { logoUrl: '', address: '' };
    @track categories = [];
    @track services = [];

      // --- ESTADO DE DISPONIBILIDAD ---
    @track diasDisponiblesList = [];
    @track horasDisponiblesList = [];
    @track isLoadingHours = false;
    @track isConfirming = false; // Nueva bandera para evitar doble clic
    isRecoordinando = false;
    oldAppointmentId = null;


    @track persona = { id: '', firstName: '', lastName: '', celular: '', email: '', indicaciones: '', hasAllergies: false };
   
   @track reserva = { 
        grupoSel: null, 
        servicioSel: null, 
        retiro: null, 
        fechaSel: null, 
        horaSel: null, 
        formaPago: null, 
        isNewCustomer: true,
        customerId: null 
    };

    @track misTurnosLogin = { celular: '' };
    @track misTurnosEncontrados = []; // Array real para los resultados
    @track isLoadingTurnos = false;

    selectedCountryCode = '+598';
    selectedCountryCodeMisTurnos = '+598';

    get countriesConfigReserva() {
        return this.getCountriesList(this.selectedCountryCode);
    }

    get countriesConfigMisTurnos() {
        return this.getCountriesList(this.selectedCountryCodeMisTurnos);
    }

    getCountriesList(selectedCode) {
        return [
            { code: '+598', label: '🇺🇾 +598', selected: selectedCode === '+598' },
            { code: '+54', label: '🇦🇷 +54', selected: selectedCode === '+54' },
            { code: '+55', label: '🇧🇷 +55', selected: selectedCode === '+55' },
            { code: '+56', label: '🇨🇱 +56', selected: selectedCode === '+56' },
            { code: '+1', label: '🇺🇸 +1', selected: selectedCode === '+1' },
            { code: '+34', label: '🇪🇸 +34', selected: selectedCode === '+34' }
        ];
    }
    @track isLoadingTurnos = false;

    tieneIndicaciones = false;
    mostrarSubOpcionesRetiro = false;

    // --- GETTERS: NAVEGACIÓN ---
    get isWelcome()     { return this.currentScreen === 'welcome'; }
    get isReserva()     { return this.currentScreen === 'reserva'; }
    get isMisTurnos()   { return this.currentScreen === 'misTurnos'; }
    get isPrecios()     { return this.currentScreen === 'precios'; }
    get isConsulta()    { return this.currentScreen === 'consulta'; }

    // --- SELECCION MULTIPLE ---
    @track selectedServiceIds = [];
    showMaxServicesWarning = false;

    get groupedServicesUI() {
        return this.categories.map(cat => {
            const hasSelectedInCategory = this.services
                .filter(s => s.Grupo_Servicio__c === cat.id)
                .some(s => this.selectedServiceIds.includes(s.Id));

            const catServices = this.services
                .filter(s => s.Grupo_Servicio__c === cat.id)
                .map(s => {
                    const isSelected = this.selectedServiceIds.includes(s.Id);
                    const isDisabled = hasSelectedInCategory && !isSelected;
                    
                    let cssClass = isSelected ? 'card card--service card--service-selected' : 'card card--service';
                    if (isDisabled) {
                        cssClass += ' card--disabled';
                    }
                    
                    let durText = '';
                    if (s.Duracion_Base_Min__c) {
                        durText = s.Duracion_Base_Min__c >= 60 
                            ? `${Math.floor(s.Duracion_Base_Min__c / 60)} h${s.Duracion_Base_Min__c % 60 > 0 ? ` ${s.Duracion_Base_Min__c % 60} min` : ''}` 
                            : `${s.Duracion_Base_Min__c} min`;
                    }

                    return {
                        ...s,
                        isDisabled: isDisabled,
                        cssClass: cssClass,
                        duracionFormateada: durText
                    };
                });
            return {
                ...cat,
                services: catServices,
                hasServices: catServices.length > 0
            };
        }).filter(cat => cat.hasServices);
    }

    get hasSelectedServices() {
        return this.selectedServiceIds.length > 0;
    }

    get nextButtonLabel() {
        return `Siguiente (${this.selectedServiceIds.length} servicio${this.selectedServiceIds.length > 1 ? 's' : ''})`;
    }

    // --- GETTERS: RESERVAS Y CLIENTES ---
    get isReservaPaso1() { return this.reservaStep === 1; }
    get isReservaPaso2() { return this.reservaStep === 2; }
    get isReservaPaso3() { return this.reservaStep === 3; }
    get isReservaPaso4() { return this.reservaStep === 4; }
    get isReservaPaso5() { return this.reservaStep === 5; }
    get isReservaPaso6() { return this.reservaStep === 6; } 
    get isReservaPaso7() { return this.reservaStep === 7; } 
    get isReservaPaso8() { return this.reservaStep === 8; } 

    get isMisTurnosPaso1() { return this.misTurnosStep === 1; }
    get isMisTurnosPaso2() { return this.misTurnosStep === 2; }

    get pillClaseNo() { return this.tieneIndicaciones ? 'pill' : 'pill pill--active'; }
    get pillClaseSi() { return this.tieneIndicaciones ? 'pill pill--active' : 'pill'; }

    get primerNombre() { 
        return this.persona.firstName || ''; 
    }

    get celularCompletoFormateado() {
        const country = this.getCountriesList(this.selectedCountryCode).find(c => c.selected);
        const prefix = country ? country.label : this.selectedCountryCode;
        return `${prefix} ${this.persona.celular}`;
    }

    get primerNombreMisTurnos() { return this.misTurnosLogin.nombre ? this.misTurnosLogin.nombre.split(' ')[0] : ''; }

    get isBotonConfirmarDeshabilitado() { 
        return !this.reserva.formaPago || this.isConfirming; 
    }

    get hasTurnos() {
        return this.misTurnosEncontrados && this.misTurnosEncontrados.length > 0;
    }
    get preciosAgrupados() {
        console.info('preciosAgrupados');
       return this.categories.map(cat => {
            const serviciosDelGrupo = this.services
                .filter(s => s.Grupo_Servicio__c === cat.id)
                .map(s => {
                    let durText = '';
                    if (s.Duracion_Base_Min__c) {
                        durText = s.Duracion_Base_Min__c >= 60 
                            ? `${Math.floor(s.Duracion_Base_Min__c / 60)} h${s.Duracion_Base_Min__c % 60 > 0 ? ` ${s.Duracion_Base_Min__c % 60} min` : ''}` 
                            : `${s.Duracion_Base_Min__c} min`;
                    }
                    return {
                        ...s,
                        precioFormateado: s.Precio__c.toLocaleString('es-UY'),
                        tieneDescripcion: s.Descripcion_Extendida__c && s.Descripcion_Extendida__c.trim() !== '',
                        duracionFormateada: durText
                    };
                });
            
            return { titulo: cat.label.toUpperCase(), servicios: serviciosDelGrupo };
        }).filter(g => g.servicios.length > 0);
    }

    // Reemplazamos el getter anterior por uno que use la variable del estado
    get categorias() {
        return this.categories;
    }
    
    get titlePaso4() {
        if (!this.reserva.grupoSel) return '¿Qué servicio querés reservar?';
        const cat = this.categories.find(c => c.id === this.reserva.grupoSel);
        return cat ? `¿Qué servicio querés reservar de ${cat.label}?` : '¿Qué servicio querés reservar?';
    }
    
    get serviciosFiltrados() {
        console.info('serviciosFiltrados, grupo seleccionado '+this.reserva.grupoSel);
        //console.info(JSON.stringify( this.services, null, 2));
      if (!this.reserva.grupoSel) return [];
        
        const filteredServices = this.services
            .filter(s => s.Grupo_Servicio__c === this.reserva.grupoSel)
            .map(s => {
                let durText = s.Duracion_Base_Min__c >= 60 
                    ? `${Math.floor(s.Duracion_Base_Min__c / 60)} H${s.Duracion_Base_Min__c % 60 > 0 ? ` ${s.Duracion_Base_Min__c % 60} MIN` : ''}` 
                    : `${s.Duracion_Base_Min__c} MIN`;
                
                return { 
                    ...s, 
                    precioFormateado: s.Precio__c.toLocaleString('es-UY'),
                    duracionFormateada: durText, 
                    tieneDescripcion: s.Descripcion_Extendida__c && s.Descripcion_Extendida__c.trim() !== '' 
                };
            });

            //console.info(JSON.stringify( filteredServices, null, 2));
            return filteredServices;
    }

    get servicioSeleccionadoInfo() {
        //console.info('servicioSeleccionadoInfo...: '+this.reserva.servicioSel); 
        if (!this.reserva.servicioSel) return null;
        const service =  this.serviciosFiltrados.find(s => s.Id === this.reserva.servicioSel);
        //console.info('servicioSeleccionadoInfo: '+JSON.stringify(service, null, 2));
        return service
    }

    get servicioCabeceraInfo() {
        if (!this.selectedServiceIds || this.selectedServiceIds.length === 0) return null;
        
        let nombres = [];
        let totalMinutos = 0;
        
        this.selectedServiceIds.forEach(id => {
            const s = this.services.find(srv => srv.Id === id);
            if (s) {
                nombres.push(s.Nombre_Visible__c);
                totalMinutos += s.Duracion_Base_Min__c || 0;
            }
        });
        
        let duracionFormateada = totalMinutos >= 60 
            ? `${Math.floor(totalMinutos / 60)} H${totalMinutos % 60 > 0 ? ` ${totalMinutos % 60} MIN` : ''}` 
            : `${totalMinutos} MIN`;
            
        return {
            nombre: nombres.join(' y '),
            duracion: duracionFormateada
        };
    }

    get isBotonFechaContinuarDeshabilitado() { return !this.reserva.horaSel; }

    get todayIso() {
        const d = new Date();
        return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    }

  get resumenDatos() {
        console.info('resumen datos');
        console.info(JSON.stringify(this.reserva, null, 2));
        if (!this.reserva.servicioSel || !this.reserva.fechaSel || !this.reserva.slotData) return {};
        
        let totalCalculado = 0;
        let descripcionesArr = [];
        this.selectedServiceIds.forEach(id => {
            const service = this.services.find(s => s.Id === id);
            if (service && service.Precio__c) {
                totalCalculado += service.Precio__c;
            }
            if (service && service.Descripcion_Extendida__c) {
                descripcionesArr.push(service.Descripcion_Extendida__c);
            }
        });
        
        if (this.reserva.retiro && this.reserva.retiro.material === 'blando') totalCalculado += 200;
        if (this.reserva.retiro && this.reserva.retiro.material === 'duro') totalCalculado += 300;
        
        // Extraemos los datos formateados directamente desde la respuesta de Apex
        const combo = this.reserva.slotData;
        const firstSlot = combo.slots[0];
        
        let serviciosArr = [];
        let profsArr = [];
        let profsSet = new Set();
        let totalMinutos = 0;
        
        combo.slots.forEach(s => {
            serviciosArr.push(s.serviceName);
            if (!profsSet.has(s.employeeName)) {
                profsSet.add(s.employeeName);
                profsArr.push(s.employeeName);
            }
            totalMinutos += s.durationMinutes || 0;
        });

        const servicioNombre = serviciosArr.join(' y ');
        const servicioLabel = serviciosArr.length > 1 ? 'SERVICIOS' : 'SERVICIO';
        const profNombre = profsArr.join(' y ');
        const profLabel = profsArr.length > 1 ? 'PROFESIONALES' : 'PROFESIONAL';
        const descripcionServicio = descripcionesArr.join(' | ');

        return { 
            cliente: `${this.persona.firstName} ${this.persona.lastName}`.trim(),
            servicio: servicioNombre, 
            servicioLabel: servicioLabel,
            profesional: profNombre, 
            profesionalLabel: profLabel,
            fecha: `${firstSlot.dayOfTheWeek} ${firstSlot.dayNumber} de ${firstSlot.monthName}`, // Ej: Miércoles 5 de Mayo
            hora: combo.timeFormatted, 
            duracion: totalMinutos > 0 ? `${totalMinutos} min` : 'Varios min', 
            total: totalCalculado,
            descripcionServicio: descripcionServicio
        };
    }

    get hasHorasDisponibles() {
        return this.horasDisponiblesList && this.horasDisponiblesList.length > 0;
    }

    get opcionesPago() {
        const opciones = ['Efectivo', 'Transferencia', 'Decido en el momento'];
        return opciones.map(op => ({ label: op, cssClass: this.reserva.formaPago === op ? 'pill pill--active' : 'pill' }));
    }

    get isBotonConfirmarDeshabilitado() { return !this.reserva.formaPago; }

    get googleCalendarUrl() {
        if (!this.reserva.fechaSel || !this.reserva.horaSel) return '#';
        
        const fechaParts = this.reserva.fechaSel.split('-');
        const horaParts = this.reserva.horaSel.split(':');
        const start = new Date(fechaParts[0], fechaParts[1] - 1, fechaParts[2], horaParts[0], horaParts[1]);
        
        let durationMins = 0;
        if (this.reserva.slotData && this.reserva.slotData.slots) {
            this.reserva.slotData.slots.forEach(s => durationMins += s.durationMinutes || 0);
        }
        const end = new Date(start.getTime() + durationMins * 60000);

        const formatGCalDate = (d) => {
            return d.getFullYear() + 
                   String(d.getMonth() + 1).padStart(2, '0') + 
                   String(d.getDate()).padStart(2, '0') + 'T' + 
                   String(d.getHours()).padStart(2, '0') + 
                   String(d.getMinutes()).padStart(2, '0') + '00';
        };

        const branchName = this.businessInfo && this.businessInfo.branchName ? this.businessInfo.branchName : 'nuestro local';
        const title = encodeURIComponent(`Reserva de ${this.resumenDatos.servicio} en ${branchName}`);
        const dates = `${formatGCalDate(start)}/${formatGCalDate(end)}`;
        let detailsText = `Te esperamos para tu servicio de ${this.resumenDatos.servicio}.`;
        if (this.resumenDatos.descripcionServicio) {
            detailsText += `\n\nDetalles del servicio:\n${this.resumenDatos.descripcionServicio}`;
        }
        const details = encodeURIComponent(detailsText);
        const location = encodeURIComponent(this.businessInfo && this.businessInfo.address ? this.businessInfo.address : '');

        return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&dates=${dates}&details=${details}&location=${location}`;
    }

    handleDownloadIcs() {
        if (!this.reserva.fechaSel || !this.reserva.horaSel) return;
        
        const fechaParts = this.reserva.fechaSel.split('-');
        const horaParts = this.reserva.horaSel.split(':');
        const start = new Date(fechaParts[0], fechaParts[1] - 1, fechaParts[2], horaParts[0], horaParts[1]);
        
        let durationMins = 0;
        if (this.reserva.slotData && this.reserva.slotData.slots) {
            this.reserva.slotData.slots.forEach(s => durationMins += s.durationMinutes || 0);
        }
        const end = new Date(start.getTime() + durationMins * 60000);

        const formatIcsDate = (d) => {
            return d.getFullYear() + 
                   String(d.getMonth() + 1).padStart(2, '0') + 
                   String(d.getDate()).padStart(2, '0') + 'T' + 
                   String(d.getHours()).padStart(2, '0') + 
                   String(d.getMinutes()).padStart(2, '0') + '00';
        };

        const branchName = this.businessInfo && this.businessInfo.branchName ? this.businessInfo.branchName : 'nuestro local';
        const title = `Reserva de ${this.resumenDatos.servicio} en ${branchName}`;
        let description = `Te esperamos para tu servicio de ${this.resumenDatos.servicio}.`;
        if (this.resumenDatos.descripcionServicio) {
            description += `\\n\\nDetalles del servicio:\\n${this.resumenDatos.descripcionServicio}`;
        }
        const location = this.businessInfo && this.businessInfo.address ? this.businessInfo.address : '';

        const icsContent = [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//Bookit//App//ES',
            'BEGIN:VEVENT',
            `UID:${new Date().getTime()}@bookit.com`,
            `DTSTAMP:${formatIcsDate(new Date())}`,
            `DTSTART:${formatIcsDate(start)}`,
            `DTEND:${formatIcsDate(end)}`,
            `SUMMARY:${title}`,
            `DESCRIPTION:${description}`,
            `LOCATION:${location}`,
            'END:VEVENT',
            'END:VCALENDAR'
        ].join('\\r\\n');

        const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'reserva.ics';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // --- ACCIONES GENERALES ---

    connectedCallback() {

        // TODO this is for testing. Remove it for prod
        //if(!this.businessId){
        //    this.businessId = 'a02gL00000Ix6AHQAZ';
        //}
        if(this.businessId) {
            this.loadData();
        } else{
            console.error('no business selected');
        }
    }

    async loadData() {
        console.info('loading data for the business: '+this.businessId);
        try {
            // Cargamos categorías, servicios e info del negocio en paralelo para ganar velocidad
            const [categoriesDB, servicesDB, businessDB] = await Promise.all([
                getCategories({ businessId: this.businessId }),
                getServices({ businessId: this.businessId }),
                getBusinessInfo({ businessId: this.businessId })
            ]);

            if (businessDB) {
                let defaultWaUrl = 'https://wa.me/message/PUX7XCBYPK4MN1';
                if (businessDB.Phone_Number__c) {
                    const cleanPhone = businessDB.Phone_Number__c.replace(/[^0-9]/g, '');
                    defaultWaUrl = `https://wa.me/${cleanPhone}?text=${encodeURIComponent('Hola, tengo una consulta')}`;
                }
                
                this.businessInfo = {
                    logoUrl: businessDB.Logo_URL__c || '',
                    address: businessDB.Address__c || '',
                    whatsappUrl: defaultWaUrl,
                    branchName: businessDB.Branch_Name || 'nuestro local'
                };
            }

            console.info('categoriesDB: ');
            console.info(JSON.stringify(categoriesDB, null, 2));
            console.info('servicesDB: ');
            console.info(JSON.stringify(servicesDB, null, 2));

            // Mapeamos las categorías para mantener las clases CSS y la estructura
            this.categories = categoriesDB.map(cat => {
                // Lógica para detectar si es la tarjeta acentuada (Manos y Pies)
                const esCombinado = cat.Name.toLowerCase().includes('y'); 
                
                return {
                    id: cat.Id,
                    label: cat.Display_Name__c ? cat.Display_Name__c : cat.Name,
                    sub: cat.Description_Short__c,
                    cssClass: esCombinado ? 'card card--accent between-rows' : 'card between-rows'
                };
            });

            // Mapeamos servicios (asegúrate de que Category__c ahora traiga el Id del Lookup)
            this.services = servicesDB.map(s => ({
                Id: s.Id,
                Nombre_Visible__c: s.Display_Name__c ? s.Display_Name__c : s.Name,
                Duracion_Base_Min__c: s.Duration_Minutes__c,
                Precio__c: s.Price__c,
                Grupo_Servicio__c: s.AA_Service_Category__c, // Ahora es el ID de la categoría
                Descripcion_Extendida__c: s.Description__c || '',
                Requires_Manual_Coordination__c: s.Requires_Manual_Coordination__c
            }));

        } catch (error) {
            console.error('Error cargando datos:' + JSON.stringify(error));
        }
    }

    handleInputChange(event) { this.persona[event.target.dataset.id] = event.target.value; }

    handleCheckboxChange(event) {
        this.persona[event.target.dataset.id] = event.target.checked;
    }
    
    formatPhoneNumber(val, countryCode) {
        if (!val) return '';
        // 1. Quitar todo lo que no sea dígito
        let digits = val.replace(/\D/g, '');
        
        // 2. Si es Uruguay, formatear a XX XXX XXX
        if (countryCode === '+598') {
            if (digits.startsWith('0')) {
                digits = digits.substring(1);
            }
            let formatted = '';
            if (digits.length > 0) {
                formatted = digits.substring(0, 2);
            }
            if (digits.length > 2) {
                formatted += ' ' + digits.substring(2, 5);
            }
            if (digits.length > 5) {
                formatted += ' ' + digits.substring(5, 8);
            }
            return formatted;
        }
        
        // Para otros países, dejar los dígitos de corrido
        return digits;
    }

    handlePhoneInput(event) {
        let val = event.target.value;
        const formatted = this.formatPhoneNumber(val, this.selectedCountryCode);
        event.target.value = formatted;
        this.persona.celular = formatted;
    }

    handleCountryChange(event) {
        this.selectedCountryCode = event.target.value;
        this.persona.celular = this.formatPhoneNumber(this.persona.celular, this.selectedCountryCode);
    }


    
    handleToggleService(event) {
        const srvId = event.currentTarget.dataset.id;
        
        const srv = this.services.find(s => s.Id === srvId);
        if (srv) {
            const catId = srv.Grupo_Servicio__c;
            const hasSelectedInCategory = this.services
                .filter(s => s.Grupo_Servicio__c === catId)
                .some(s => this.selectedServiceIds.includes(s.Id));
            
            const isSelected = this.selectedServiceIds.includes(srvId);
            if (hasSelectedInCategory && !isSelected) {
                return;
            }
        }

        this.showMaxServicesWarning = false;
        
        if (this.selectedServiceIds.includes(srvId)) {
            // Deseleccionar
            this.selectedServiceIds = this.selectedServiceIds.filter(id => id !== srvId);
        } else {
            // Seleccionar (máximo 2)
            if (this.selectedServiceIds.length >= 2) {
                this.showMaxServicesWarning = true;
                // Ocultar el mensaje después de 3 segundos
                setTimeout(() => { this.showMaxServicesWarning = false; }, 3000);
            } else {
                this.selectedServiceIds = [...this.selectedServiceIds, srvId];
            }
        }
    }

    handleWhatsAppRedirect(event) {
        event.stopPropagation();
        const srvId = event.currentTarget.dataset.id;
        const srv = this.services.find(s => s.Id === srvId);
        if (srv) {
            const serviceName = srv.Nombre_Visible__c;
            const businessPhone = this.businessInfo.whatsappUrl ? this.businessInfo.whatsappUrl.match(/\d+/) : null;
            const phone = businessPhone ? businessPhone[0] : '';
            
            const text = `Hola, me gustaría consultar por el servicio de ${serviceName}`;
            const url = `https://wa.me/${phone}?text=${encodeURIComponent(text)}`;
            window.open(url, '_blank');
        }
    }

    handleContinuarServicios() {
        if (this.selectedServiceIds.length === 0) return;
        
        // Para la compatibilidad de la UI, usaremos el primer servicio en el flow existente
        const firstSrvId = this.selectedServiceIds[0];
        this.reserva.servicioSel = firstSrvId;
        
        // Verificar si algún servicio seleccionado requiere retiro
        const requiereRetiro = this.selectedServiceIds.some(id => {
            const s = this.services.find(srv => srv.Id === id);
            return s && s.Requiere_Pregunta_Retiro__c;
        });
        
        if (requiereRetiro) {
            this.reservaStep = 5;
        } else {
            this.goToStep6();
        }
    }

   
    handleSelectRetiro(event) {
        const tipo = event.currentTarget.dataset.tipo; 
        this.reserva.retiro = { tipo: tipo };
        if (tipo === 'externo') { 
            this.mostrarSubOpcionesRetiro = true; 
        } else { 
            this.mostrarSubOpcionesRetiro = false; 
            this.goToStep6(); 
        }
    }

    handleSelectRetiroMaterial(event) { 
        this.reserva.retiro.material = event.target.dataset.material; 
        this.mostrarSubOpcionesRetiro = false; 
        this.goToStep6(); 
    }

    handleSelectFecha(event) { this.reserva.fechaSel = event.currentTarget.dataset.fecha; this.reserva.horaSel = null; }
    handleSelectHora(event) { this.reserva.horaSel = event.currentTarget.dataset.hora; }
    handleSelectPago(event) { this.reserva.formaPago = event.target.dataset.pago; }
    
    async handleConfirmarReserva() {
        this.isConfirming = true; // Deshabilita el botón
        
        try {
            // Tomamos los datos de nuestro estado local
            // slotData is now an AA_ComboSlot
            let nuevaReserva;
            if (this.isRecoordinando) {
                // If it's a rescheduling, we assume it's only 1 service for now and take the first slot's employee
                nuevaReserva = await recoordinarAppointment({
                    oldAppointmentId: this.oldAppointmentId,
                    customerId: this.persona.id,
                    employeeId: this.reserva.slotData.slots[0].employeeId,
                    serviceId: this.reserva.servicioSel, // this might need to be selectedServiceIds[0] if we change the meaning of servicioSel
                    dayString: this.reserva.fechaSel,
                    hourString: this.reserva.horaSel
                });
                
                // Limpiar estado
                this.isRecoordinando = false;
                this.oldAppointmentId = null;
            } else {
                const params = {
                    customerId: this.persona.id,
                    comboSlotJson: JSON.stringify(this.reserva.slotData),
                    formaPago: this.reserva.formaPago
                };
                console.info('Enviando datos de reserva combo a Salesforce:', JSON.stringify(params));
                const apps = await saveComboAppointments(params);
                nuevaReserva = apps[0]; // just grab the first one to show success
            }
            
            console.info('¡Reserva creada exitosamente!', nuevaReserva.Id);
            
            // Avanzamos a la pantalla de éxito (Paso 8)
            this.reservaStep = 8; 

        } catch (error) {
            console.error('Error al crear la reserva:', JSON.stringify(error));
            alert('Hubo un problema al procesar tu reserva. Por favor, intenta nuevamente.');
        } finally {
            this.isConfirming = false; // Rehabilitar botón por si falló y quiere reintentar
        }
    }
    
    handleMisTurnosInput(event) { 
        const fieldId = event.target.dataset.id;
        let val = event.target.value;

        if (fieldId === 'celular') {
            const formatted = this.formatPhoneNumber(val, this.selectedCountryCodeMisTurnos);
            event.target.value = formatted;
            this.misTurnosLogin[fieldId] = formatted; 
        } else {
            this.misTurnosLogin[fieldId] = val; 
        }
    }

    handleCountryChangeMisTurnos(event) {
        this.selectedCountryCodeMisTurnos = event.target.value;
        this.misTurnosLogin.celular = this.formatPhoneNumber(this.misTurnosLogin.celular, this.selectedCountryCodeMisTurnos);
    }
   
    getFormattedPhoneForApex(countryCode, localNumber) {
        if (!localNumber) return '';
        // Limpiar cualquier espacio o caracter no numérico
        let cleanLocalNumber = localNumber.replace(/\D/g, '');
        
        // Si el usuario por alguna razón logró ingresar un 0 inicial para Uruguay, lo quitamos
        if (countryCode === '+598' && cleanLocalNumber.startsWith('0')) {
            cleanLocalNumber = cleanLocalNumber.substring(1);
        }

        return countryCode + cleanLocalNumber;
    }

    async handleBuscarTurnos() {
        if (!this.misTurnosLogin.celular) {
            alert('Por favor, ingresá tu celular para buscar tus turnos.');
            return;
        }

        this.isLoadingTurnos = true;
        const fullPhone = this.getFormattedPhoneForApex(this.selectedCountryCodeMisTurnos, this.misTurnosLogin.celular);

        try {
            const turnosDB = await getMisTurnos({ celular: fullPhone, businessId:this.businessId });

            const DOW = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
            const MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'];

            // Mapeamos los datos de Salesforce para la vista
            this.misTurnosEncontrados = turnosDB.map(t => {
                // Instanciamos la fecha. Si usas fechas UTC desde Apex, asegúrate de la zona horaria.
                const dt = new Date(t.Start_Date_Time__c);
                
                let isConfirmado = false;
                if (t.Customer_Confirmation_Date__c) {
                    isConfirmado = true;
                } else if (t.Internal_Comments__c && t.Internal_Comments__c.includes('Confirmado por el cliente')) {
                    isConfirmado = true;
                }
                
                let horaFormateada = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit', hour12: true });
                horaFormateada = horaFormateada.replace(/\.?\s?[ap]\.?\s?m\.?/i, match => {
                    return match.toLowerCase().includes('p') ? ' PM' : ' AM';
                }).trim();

                let svcName = t.Service__r ? (t.Service__r.Display_Name__c ? t.Service__r.Display_Name__c : t.Service__r.Name) : 'Servicio';
                if (t.Duration_Minutes__c) {
                    let durText = t.Duration_Minutes__c >= 60
                        ? `${Math.floor(t.Duration_Minutes__c / 60)} H${t.Duration_Minutes__c % 60 > 0 ? ` ${t.Duration_Minutes__c % 60} MIN` : ''}`
                        : `${t.Duration_Minutes__c} MIN`;
                    svcName += `, ${durText}`;
                }

                return {
                    Id: t.Id,
                    fechaStr: `${DOW[dt.getDay()]} ${dt.getDate()} de ${MESES[dt.getMonth()]}`,
                    // Formato HH:mm AM/PM
                    horaStr: horaFormateada,
                    servicio: svcName,
                    profesional: t.Employee__r ? ((t.Employee__r.First_Name__c ? t.Employee__r.First_Name__c + ' ' : '') + t.Employee__r.Last_Name__c) : 'El equipo',
                    status: t.Status__c,
                    startDateTimeObj: dt,
                    confirmText: isConfirmado ? 'Asistencia confirmada' : 'Confirmar asistencia',
                    isConfirmDisabled: isConfirmado,
                    showMessage: false,
                    messageText: '',
                    customerId: t.Customer__c,
                    serviceId: t.Service__c,
                    employeeId: t.Employee__r ? t.Employee__r.Id : t.Employee__c
                };
            });

            this.misTurnosStep = 2;

        } catch (error) {
            console.error('Error buscando mis turnos:', JSON.stringify(error));
            alert('Hubo un problema al buscar tus turnos. Intentá de nuevo.');
        } finally {
            this.isLoadingTurnos = false;
        }
    }
   
    async handleConfirmarAsistencia(event) {
        const appointmentId = event.currentTarget.dataset.id;
        if (!appointmentId) return;

        const turno = this.misTurnosEncontrados.find(t => t.Id === appointmentId);
        if (!turno) return;
        
        // Limpiamos mensajes previos
        turno.showMessage = false;

        const timeDiff = turno.startDateTimeObj.getTime() - new Date().getTime();
        const hoursDiff = timeDiff / (1000 * 3600);

        if (hoursDiff > 24) {
            turno.showMessage = true;
            turno.messageText = 'La cita puede ser confirmada dentro de las 24hs antes de la cita';
            turno.isConfirmDisabled = true;
            this.misTurnosEncontrados = [...this.misTurnosEncontrados];
            return;
        }

        turno.confirmText = 'Enviando...';
        turno.isConfirmDisabled = true;
        this.misTurnosEncontrados = [...this.misTurnosEncontrados];
        
        try {
            console.info('Confirmando asistencia en Salesforce con ID:', appointmentId);
            await confirmarAsistencia({ appointmentId: appointmentId });
            console.info('Asistencia confirmada con éxito.');
            await this.handleBuscarTurnos();
        } catch (error) {
            console.error('Error al confirmar asistencia:', JSON.stringify(error));
            alert('Hubo un problema al confirmar tu asistencia. Por favor, intenta nuevamente.');
            this.isLoadingTurnos = false;
        }
    }
    
    handleRecoordinar(event) {
        const appointmentId = event.currentTarget.dataset.id;
        if (!appointmentId) return;

        const turno = this.misTurnosEncontrados.find(t => t.Id === appointmentId);
        if (!turno) return;

        turno.showMessage = false;
        const timeDiff = turno.startDateTimeObj.getTime() - new Date().getTime();
        const hoursDiff = timeDiff / (1000 * 3600);

        if (hoursDiff < 12) {
            turno.showMessage = true;
            turno.messageText = 'La cita no puede ser recoordinada con menos de 12 horas de anticipacion. Ponerse en contacto con el salon';
            this.misTurnosEncontrados = [...this.misTurnosEncontrados];
            return;
        }

        // Configurar estado para recoordinar
        this.isRecoordinando = true;
        this.oldAppointmentId = appointmentId;
        this.reserva.customerId = turno.customerId;
        this.reserva.servicioSel = turno.serviceId;
        this.selectedServiceIds = [turno.serviceId]; // Agregado para getComboSlots
        this.reserva.profesionalSel = turno.employeeId;
        this.persona.id = turno.customerId;
        
        // Navegar al paso de selección de fecha/hora
        this.currentScreen = 'reserva';
        this.goToStep6();
    }
    
    async handleCancelarTurno(event) {
        // Obtenemos el Id del turno desde el dataset del botón configurado en el HTML
        const appointmentId = event.currentTarget.dataset.id;
        
        if (!appointmentId) return;

        const turno = this.misTurnosEncontrados.find(t => t.Id === appointmentId);
        if (!turno) return;

        turno.showMessage = false;
        const timeDiff = turno.startDateTimeObj.getTime() - new Date().getTime();
        const hoursDiff = timeDiff / (1000 * 3600);

        if (hoursDiff < 12) {
            turno.showMessage = true;
            turno.messageText = 'La cita no puede ser cancelada con menos de 12 horas de anticipacion. Ponerse en contacto con el salon';
            this.misTurnosEncontrados = [...this.misTurnosEncontrados];
            return;
        }

        this.isLoadingTurnos = true;

        try {
            console.info('Cancelando turno en Salesforce con ID:', appointmentId);
            
            // Llamada al backend
            await cancelarAppointment({ appointmentId: appointmentId });
            
            console.info('Turno cancelado con éxito.');
            
            // Refrescamos la lista de turnos llamando al método que ya consulta el backend
            // Esto asegura que la UI se actualice sola de inmediato
            await this.handleBuscarTurnos();

        } catch (error) {
            console.error('Error al cancelar el turno:', JSON.stringify(error));
            alert('Hubo un problema al cancelar tu turno. Por favor, intenta nuevamente.');
            this.isLoadingTurnos = false;
        }
    }

    // --- NAVEGACIÓN ---
    navToWelcome()     { this.currentScreen = 'welcome'; this.resetReserva(); }
    navToMisTurnos()   { this.currentScreen = 'misTurnos'; this.misTurnosStep = 1; }
    navToPrecios()     { this.currentScreen = 'precios'; }
    navToConsulta()    { this.currentScreen = 'consulta'; }
    navToReserva()     { this.currentScreen = 'reserva'; this.reservaStep = 1; this.resetReserva(); }

    resetReserva() {
        this.selectedServiceIds = [];
        this.reserva.servicioSel = null;
        this.reserva.fechaSel = null;
        this.reserva.horaSel = null;
        this.reserva.formaPago = null;
        this.reserva.slotData = null;
    }

    //avanzarPaso2() { this.reservaStep = 2; }

    async avanzarPaso2() {
        // 1. Validación básica del frontend
        if (!this.persona.celular) {
            alert('Por favor, ingresa tu número de celular para continuar.');
            return;
        }

        try {
            // 2. Llamada al backend (Apex)
            const fullPhone = this.getFormattedPhoneForApex(this.selectedCountryCode, this.persona.celular);
            const clienteExistente = await getOrCreateCustomer({ phoneNumber: fullPhone, businessId: this.businessId });
            
            if (clienteExistente.Email__c) {
                console.log('Cliente encontrado en SF: '+ clienteExistente.Id);
                this.reserva.isNewCustomer = false;
                this.persona.email = clienteExistente.Email__c || '';
                this.reserva.customerId = clienteExistente.Id; 
                this.persona.id = clienteExistente.Id; 
                this.persona.firstName = clienteExistente.First_Name__c || '';
                this.persona.lastName = clienteExistente.Last_Name__c || '';
                this.reservaStep = 3;

            } else {
                console.log('No se encontraron registros. Es cliente fue creado con el id: '+ clienteExistente.Id);
                this.reserva.isNewCustomer = true;
                this.reserva.customerId = clienteExistente.Id; 
                this.persona.id = clienteExistente.Id; 
                this.reservaStep = 2; 
            }
            console.info('reserva: ');
            console.info(JSON.stringify(this.reserva));
            console.info('persona: ');
            console.info(JSON.stringify(this.persona));

        } catch (error) {
            console.error('Error al consultar Apex:'+ JSON.stringify(error));
            
            let errorMessage = 'Hubo un problema al procesar tus datos. Por favor, intenta nuevamente.';
            if (error) {
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.body && error.body.fieldErrors && Object.keys(error.body.fieldErrors).length > 0) {
                    const fieldName = Object.keys(error.body.fieldErrors)[0];
                    errorMessage = error.body.fieldErrors[fieldName][0].message;
                } else if (error.body && error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errorMessage = error.body.pageErrors[0].message;
                } else if (error.message) {
                    errorMessage = error.message;
                }
            }
            alert(errorMessage);
            // TODO
            //this.reservaStep = 2; 

        }
    }

    volverPaso1()  { this.reservaStep = 1; }

    async avanzarPaso3() { 

        if (!this.persona.firstName || !this.persona.firstName.trim()) {
            alert('Por favor, ingresá tu nombre para continuar.');
            return;
        }
        if (!this.persona.lastName || !this.persona.lastName.trim()) {
            alert('Por favor, ingresá tu apellido para continuar.');
            return;
        }
        if (!this.persona.email || !this.persona.email.trim()) {
            alert('Por favor, ingresá tu email para continuar.');
            return;
        }
      
        // update customer
        try{
            const data = { 
                customerId: this.persona.id, 
                firstName: this.persona.firstName, 
                lastName: this.persona.lastName,
                email: this.persona.email,
                comments: this.persona.indicaciones,
                hasAllergies: this.persona.hasAllergies
            };
            console.info('data to update:');
            console.info(JSON.stringify(data));
            const customer = await updateCustomer(data);
            console.info('customer updated: '+customer.Id);

            this.reservaStep = 3; 
        }catch(error){
            console.error('Error updating customer:'+JSON.stringify(error));
            alert(JSON.stringify(error));
        }
       
        }
    //volverPaso2()  { this.reservaStep = 2; }

    volverPaso2() {
        if (this.reserva.isNewCustomer) {
            // Si es nuevo, vuelve a la pantalla de email/indicaciones
            this.reservaStep = 2;
        } else {
            // Si es conocido, vuelve directo al inicio (Nombre/Celular)
            this.reservaStep = 1;
        }
    }
    
    volverPaso3()  { this.reservaStep = 3; }
    volverPaso4()  { this.mostrarSubOpcionesRetiro = false; this.reservaStep = 3; }
    volverPaso5()  { this.reservaStep = 5; }
    volverPasoDesde6() {
        const requiereRetiro = this.selectedServiceIds.some(id => {
            const s = this.services.find(srv => srv.Id === id);
            return s && s.Requiere_Pregunta_Retiro__c;
        });
        if (requiereRetiro) { this.reservaStep = 5; } else { this.reservaStep = 3; }
    }
    avanzarPaso7() { this.reservaStep = 7; } 
    volverPaso6()  { this.reservaStep = 6; }
    volverMisTurnosPaso1() { this.misTurnosStep = 1; }

     // --- DISPONIBILIDAD LÓGICA ---
    goToStep6() {
        console.info('goToStep6');
        
        let d = new Date();
        while (d.getDay() === 0) { // skip sunday
            d.setDate(d.getDate() + 1);
        }
        
        this.reserva.fechaSel = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
        
        this.generarDiasDisponibles(d);
        this.reservaStep = 6;
    }

    handleDatePick(event) {
        const selectedIso = event.target.value;
        if (selectedIso) {
            this.reserva.fechaSel = selectedIso;
            this.reserva.horaSel = null;
            const parts = selectedIso.split('-');
            const d = new Date(parts[0], parts[1] - 1, parts[2]);
            this.generarDiasDisponibles(d);
        }
    }

    generarDiasDisponibles(startDateObj) {
        console.info('generarDiasDisponibles');
        const DOW = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
        const MESES = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
        let dias = []; 
        
        let start = new Date(startDateObj);
        
        let i = 0;
        let added = 0;
        while(added < 5) {
            let d = new Date(start); 
            d.setDate(d.getDate() + i);
            i++;
            if(d.getDay() === 0) continue; // Salteamos domingos
            
            let iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
            let isSelected = (iso === this.reserva.fechaSel);
            
            dias.push({ 
                iso: iso, 
                dow: DOW[d.getDay()], 
                num: d.getDate(), 
                mon: MESES[d.getMonth()], 
                cssClass: isSelected ? 'day-pill day-pill--selected' : 'day-pill'
            });
            added++;
        }

        // Si la fecha seleccionada no está en los botones (ej: eligieron un domingo), se queda sin seleccionar
        
        this.diasDisponiblesList = dias;
        this.fetchHorasDisponibles();
    }

   async fetchHorasDisponibles() {
        console.info('fetchHorasDisponibles, date: '+this.reserva.fechaSel+' service: '+this.reserva.servicioSel);
        if (!this.reserva.fechaSel || !this.reserva.servicioSel) return;
        //console.info(JSON.stringify(this.reserva, null, 2));
        
        this.isLoadingHours = true;
        this.horasDisponiblesList = [];
        this.reserva.horaSel = null; 
        this.reserva.slotData = null; // Limpiamos el objeto guardado previamente

        try {
            const params = { 
                serviceIds: this.selectedServiceIds,  
                targetDateStr: this.reserva.fechaSel 
            };
            console.info('getComboSlots params: '+JSON.stringify(params));
            const comboSlots = await getComboSlots(params);
            
            // Desduplicación: Si hay dos combos a la misma hora, mostramos un solo botón.
            const uniqueTimes = new Map();
            console.info('comboSlots');
            console.info(JSON.stringify(comboSlots, null, 2));
            comboSlots.forEach(combo => {
                // Usamos timeFormatted (Ej: '09:00') como clave única
                if (!uniqueTimes.has(combo.timeFormatted)) {
                    let clusterValid = combo.slots.every(s => s.isClusterStrategy);
                    let minGapValid = combo.slots.every(s => s.isMinGapStrategy);
                    
                    uniqueTimes.set(combo.timeFormatted, { 
                        val: combo.timeFormatted, 
                        cssClass: 'slot-btn',
                        isClusterDisabled: !clusterValid,
                        clusterStyle: clusterValid ? '' : 'opacity: 0.3; pointer-events: none;',
                        isMinGapDisabled: !minGapValid,
                        minGapStyle: minGapValid ? '' : 'opacity: 0.3; pointer-events: none;',
                        slotData: combo // Guardamos el objeto AA_ComboSlot completo
                    });
                }
            });
            
            // Convertimos el Map a Array para el iterador del HTML
            let list = Array.from(uniqueTimes.values());
            
            // Ordenar por hora (ej. '08:00' antes de '09:00')
            list.sort((a, b) => a.val.localeCompare(b.val));
            
            this.horasDisponiblesList = list;
            console.info('horasDisponiblesList');
            console.info(JSON.stringify(this.horasDisponiblesList, null, 2));
            
        } catch (error) {
            console.error('Error cargando disponibilidad:', JSON.stringify(error));
        } finally {
            this.isLoadingHours = false;
        }
    }

    handleSelectFecha(event) { 
        console.info('handleSelectFecha, '+event.currentTarget.dataset.fecha);
        this.reserva.fechaSel = event.currentTarget.dataset.fecha; 
        
        // Actualizar visualmente la pastilla del día
        this.diasDisponiblesList = this.diasDisponiblesList.map(d => ({
            ...d,
            cssClass: d.iso === this.reserva.fechaSel ? 'day-pill day-pill--selected' : 'day-pill'
        }));

        this.fetchHorasDisponibles();
    }

    handleSelectHora(event) { 
        console.info('handleSelectHora, '+event.currentTarget.dataset.hora);
        this.reserva.horaSel = event.currentTarget.dataset.hora; 
        
        // Buscamos la hora seleccionada para guardar todos sus detalles
        const selectedItem = this.horasDisponiblesList.find(h => h.val === this.reserva.horaSel);
        if (selectedItem) {
            this.reserva.slotData = selectedItem.slotData;
        }
        
        // Actualizar visualmente el botón de la hora
        this.horasDisponiblesList = this.horasDisponiblesList.map(h => ({
            ...h,
            cssClass: h.val === this.reserva.horaSel ? 'slot-btn slot-btn--selected' : 'slot-btn'
        }));
    }
}