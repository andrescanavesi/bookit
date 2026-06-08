import { LightningElement, track } from 'lwc';
import getWeeklyOccupancy from '@salesforce/apex/AA_WeeklyMatrixController.getWeeklyOccupancy';

export default class AAWeeklyMatrixAdmin extends LightningElement {
    @track targetDate = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate());
    @track matrixData = null;
    @track columns = [];
    @track rows = [];
    @track isLoading = false;

    get selectedDate() {
        return this.targetDate.getFullYear() + '-' + 
               String(this.targetDate.getMonth() + 1).padStart(2, '0') + '-' + 
               String(this.targetDate.getDate()).padStart(2, '0');
    }

    get startOfWeek() {
        const d = new Date(this.targetDate);
        const day = d.getDay();
        const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
        return new Date(d.setDate(diff));
    }

    get endOfWeek() {
        const start = this.startOfWeek;
        const end = new Date(start);
        end.setDate(start.getDate() + 6);
        return end;
    }

    get formattedStartOfWeek() {
        return this.formatDate(this.startOfWeek);
    }

    get formattedEndOfWeek() {
        return this.formatDate(this.endOfWeek);
    }

    connectedCallback() {
        this.loadData();
    }

    handleDateChange(event) {
        if (event.target.value) {
            // Fix timezone offset issue when parsing date string
            const parts = event.target.value.split('-');
            this.targetDate = new Date(parts[0], parts[1] - 1, parts[2]);
            this.loadData();
        }
    }

    handlePrevWeek() {
        const d = new Date(this.targetDate.getTime());
        d.setDate(d.getDate() - 7);
        this.targetDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        this.loadData();
    }

    handleNextWeek() {
        const d = new Date(this.targetDate.getTime());
        d.setDate(d.getDate() + 7);
        this.targetDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        this.loadData();
    }

    handleCurrentWeek() {
        const d = new Date();
        this.targetDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        this.loadData();
    }

    formatDate(dateObj) {
        const day = String(dateObj.getDate()).padStart(2, '0');
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const year = dateObj.getFullYear();
        return `${day}/${month}/${year}`;
    }

    async loadData() {
        this.isLoading = true;
        try {
            // Apex expects a string in YYYY-MM-DD format
            const dateStr = this.targetDate.getFullYear() + '-' + 
                            String(this.targetDate.getMonth() + 1).padStart(2, '0') + '-' + 
                            String(this.targetDate.getDate()).padStart(2, '0');
            
            const result = await getWeeklyOccupancy({ targetDate: dateStr });
            if (result && result.branchId) {
                this.matrixData = result;
                this.buildGrid();
            } else {
                this.matrixData = null;
                this.columns = [];
                this.rows = [];
            }
        } catch (error) {
            console.error('Error loading weekly matrix:', error);
            // Show toast or generic error here in real life
        } finally {
            this.isLoading = false;
        }
    }

    buildGrid() {
        const dayNames = {
            'Monday': 'Lunes', 'Tuesday': 'Martes', 'Wednesday': 'Miércoles',
            'Thursday': 'Jueves', 'Friday': 'Viernes', 'Saturday': 'Sábado', 'Sunday': 'Domingo'
        };

        const activeDaysMap = this.matrixData.branchHours; // { "Monday": { openTime, closeTime }, ... }
        
        const tempCols = [];
        const activeDates = []; // List of YYYY-MM-DD that are active

        // First pass: Find which days of the week we should display (where branch is open)
        // We know startOfWeek is Monday.
        const d = new Date(this.startOfWeek);
        for (let i = 0; i < 7; i++) {
            const currentDate = new Date(d);
            currentDate.setDate(d.getDate() + i);
            
            const dateStr = currentDate.getFullYear() + '-' + 
                            String(currentDate.getMonth() + 1).padStart(2, '0') + '-' + 
                            String(currentDate.getDate()).padStart(2, '0');
                            
            // Get English day name
            const englishDays = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
            const dowEng = englishDays[currentDate.getDay()];
            
            if (activeDaysMap[dowEng]) {
                const shortDate = `${String(currentDate.getDate()).padStart(2, '0')}/${String(currentDate.getMonth() + 1).padStart(2, '0')}`;
                tempCols.push({
                    dateStr: dateStr,
                    dayName: dayNames[dowEng],
                    shortDate: shortDate,
                    label: `${dayNames[dowEng]} ${shortDate}`
                });
                activeDates.push(dateStr);
            }
        }
        
        this.columns = tempCols;

        // Build Rows
        const tempRows = [];
        const timeSlots = this.matrixData.timeSlots;
        
        timeSlots.forEach(tSlot => {
            const row = {
                timeSlot: tSlot,
                cells: []
            };
            
            activeDates.forEach(dateStr => {
                const dayMap = this.matrixData.matrix[dateStr];
                const cellData = dayMap ? dayMap[tSlot] : null;
                
                let isActive = false;
                let cssClass = 'matrix-cell slds-text-align_center ';
                let tooltip = '';
                
                if (cellData && cellData.status !== 'Inactivo') {
                    isActive = true;
                    if (cellData.status === 'Feriado') {
                        cssClass += 'status-feriado';
                        const holidayName = this.matrixData.holidays[dateStr] || 'Feriado';
                        tooltip = 'Feriado: ' + holidayName;
                    } else if (cellData.status === 'Libre') {
                        cssClass += 'status-libre';
                        tooltip = 'Libre - ' + cellData.capacity + ' disponibles';
                    } else if (cellData.status === 'Lleno') {
                        cssClass += 'status-lleno';
                        tooltip = 'Ocupado - ' + cellData.occupied + ' de ' + cellData.capacity;
                    } else if (cellData.status === 'Parcial') {
                        cssClass += 'status-parcial';
                        tooltip = 'Parcial - ' + cellData.occupied + ' de ' + cellData.capacity + ' ocupados';
                    }
                } else {
                    cssClass += 'status-inactivo';
                    tooltip = 'Inactivo / Fuera de horario';
                }
                
                row.cells.push({
                    id: dateStr + '_' + tSlot,
                    isActive: isActive,
                    isFeriado: (cellData && cellData.status === 'Feriado'),
                    occupied: cellData ? cellData.occupied : 0,
                    capacity: cellData ? cellData.capacity : 0,
                    cssClass: cssClass,
                    tooltip: tooltip
                });
            });
            
            tempRows.push(row);
        });
        
        this.rows = tempRows;
    }
}