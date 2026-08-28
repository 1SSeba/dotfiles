const weekDays = [ // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
    { day: 'Mo', today: 0 },
    { day: 'Tu', today: 0 },
    { day: 'We', today: 0 },
    { day: 'Th', today: 0 },
    { day: 'Fr', today: 0 },
    { day: 'Sa', today: 0 },
    { day: 'Su', today: 0 },
]

function checkLeapYear(year) {
    return (
        year % 400 == 0 ||
        (year % 4 == 0 && year % 100 != 0));
}

// Cuantos dias tiene un mes (1-based; acepta 0 y 13 y se va al anio de al lado).
//
// Antes esto eran tres funciones con una regla de paridad a mano, y la regla
// estaba mal en los bordes: getPrevMonthDays(8) daba 30 aunque julio tiene 31, y
// getNextMonthDays(7) daba 30 aunque agosto tiene 31. Efecto visible: en la
// grilla de agosto faltaba el 31 de julio, y todos los casilleros de esa primera
// fila estaban corridos un dia.
//
// El dia 0 del mes siguiente es el ultimo dia de este. A las 12 del mediodia y no
// a medianoche a proposito: hay zonas horarias donde la medianoche de cierto dia
// no existe (el cambio de hora la saltea) y Date retrocede al dia anterior.
function daysInMonthNumber(month, year) {
    return new Date(year, month, 0, 12).getDate();
}

function getMonthDays(month, year) {
    return daysInMonthNumber(month, year);
}

function getNextMonthDays(month, year) {
    return daysInMonthNumber(month + 1, year);
}

function getPrevMonthDays(month, year) {
    return daysInMonthNumber(month - 1, year);
}

function getDateInXMonthsTime(x) {
    var currentDate = new Date(); // Get the current date
    if (x == 0) return currentDate; // If x is 0, return the current date

    var targetMonth = currentDate.getMonth() + x; // Calculate the target month
    var targetYear = currentDate.getFullYear(); // Get the current year

    // Adjust the year and month if necessary
    targetYear += Math.floor(targetMonth / 12);
    targetMonth = (targetMonth % 12 + 12) % 12;

    // Create a new date object with the target year and month
    var targetDate = new Date(targetYear, targetMonth, 1);

    // Set the day to the last day of the month to get the desired date
    // targetDate.setDate(0);

    return targetDate;
}

// Clave local YYYY-MM-DD, la misma forma que usa GoogleCalendar.eventsByDate.
// A mano y no con toISOString() porque ese convierte a UTC y corre el dia.
function localDateKey(dateObject) {
    const month = String(dateObject.getMonth() + 1).padStart(2, '0');
    const day = String(dateObject.getDate()).padStart(2, '0');
    return dateObject.getFullYear() + '-' + month + '-' + day;
}

function getCalendarLayout(dateObject, highlight) {
    if (!dateObject) dateObject = new Date();
    const weekday = (dateObject.getDay() + 6) % 7; // MONDAY IS THE FIRST DAY OF THE WEEK
    const day = dateObject.getDate();
    const month = dateObject.getMonth() + 1;
    const year = dateObject.getFullYear();
    const weekdayOfMonthFirst = (weekday + 35 - (day - 1)) % 7;
    const daysInMonth = getMonthDays(month, year);
    const daysInNextMonth = getNextMonthDays(month, year);
    const daysInPrevMonth = getPrevMonthDays(month, year);

    // Fill
    var monthDiff = (weekdayOfMonthFirst == 0 ? 0 : -1);
    var toFill, dim;
    if (weekdayOfMonthFirst == 0) {
        toFill = 1;
        dim = daysInMonth;
    }
    else {
        toFill = (daysInPrevMonth - (weekdayOfMonthFirst - 1));
        dim = daysInPrevMonth;
    }
    var calendar = [...Array(6)].map(() => Array(7));
    var i = 0, j = 0;
    while (i < 6 && j < 7) {
        calendar[i][j] = {
            "day": toFill,
            "today": ((toFill == day && monthDiff == 0 && highlight) ? 1 : (
                monthDiff == 0 ? 0 : -1
            )),
            // Fecha absoluta del casillero. Date() normaliza el desborde de mes,
            // asi que monthDiff -1/0/+1 se resuelve solo.
            "dateKey": localDateKey(new Date(year, (month - 1) + monthDiff, toFill, 12))
        };
        // Increment
        toFill++;
        if (toFill > dim) { // Next month?
            monthDiff++;
            if (monthDiff == 0)
                dim = daysInMonth;
            else if (monthDiff == 1)
                dim = daysInNextMonth;
            toFill = 1;
        }
        // Next tile
        j++;
        if (j == 7) {
            j = 0;
            i++;
        }

    }
    return calendar;
}
