import type { FC } from 'react';
import { useMemo } from 'react';
import ExternalDatePicker, { registerLocale } from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import { eachYearOfInterval, eachMonthOfInterval, format } from 'date-fns';
import { es, fr, pt, ru, zhCN as zh } from 'date-fns/locale';
import uniq from 'lodash/uniq';
import { useRouter } from 'next/router';
import { useT } from '@transifex/react';
import type { DatepickerProps } from './types';

registerLocale('es', es);
registerLocale('fr', fr);
registerLocale('pt_BR', pt);
registerLocale('ru', ru);
registerLocale('zh_CN', zh);

export const Datepicker: FC<DatepickerProps> = ({
  startDate,
  endDate,
  selected,
  onSelect,
  format: dateFormat,
  resolution,
  ariaDescribedBy,
  ariaInvalid,
  ariaLabelledBy,
  ariaRequired,
  id,
  name,
  title,
  disabled,
  required,
  readOnly,
  includeDates,
}: DatepickerProps) => {
  const { locale } = useRouter();
  const t = useT();

  const years = useMemo(() => {
    const dates = eachYearOfInterval({
      start: startDate,
      end: endDate,
    });
    return dates.map((date) => format(date, 'yyyy'));
  }, [startDate, endDate]);

  const months = useMemo(() => {
    const dates = eachMonthOfInterval({
      start: startDate,
      end: endDate,
    });
    return uniq(dates.map((date) => format(date, 'LLLL')));
  }, [startDate, endDate]);

  const finalDateFormat = useMemo(() => {
    if (!dateFormat && resolution === 'month') {
      return 'MMMM yyyy';
    }

    if (!dateFormat && resolution === 'year') {
      return 'yyyy';
    }

    return dateFormat;
  }, [dateFormat, resolution]);

  return (
    <div className="m-datepicker">
      <ExternalDatePicker
        locale={locale}
        minDate={startDate}
        maxDate={endDate}
        selected={selected}
        onSelect={onSelect}
        dateFormat={finalDateFormat}
        showMonthYearPicker={resolution === 'month'}
        showFullMonthYearPicker={resolution === 'month'}
        showYearPicker={resolution === 'year'}
        popperPlacement="bottom"
        ariaDescribedBy={ariaDescribedBy}
        ariaInvalid={ariaInvalid}
        ariaLabelledBy={ariaLabelledBy}
        ariaRequired={ariaRequired}
        id={id}
        name={name}
        title={title}
        disabled={disabled}
        required={required}
        readOnly={readOnly}
        includeDates={includeDates}
        renderCustomHeader={({
          date,
          changeYear,
          changeMonth,
          decreaseYear,
          increaseYear,
          decreaseMonth,
          increaseMonth,
          prevYearButtonDisabled,
          nextYearButtonDisabled,
          prevMonthButtonDisabled,
          nextMonthButtonDisabled,
        }) => (
          <div className="popup-header">
            <button
              onClick={resolution !== 'day' ? decreaseYear : decreaseMonth}
              disabled={resolution !== 'day' ? prevYearButtonDisabled : prevMonthButtonDisabled}
              aria-label={resolution !== 'day' ? t('Previous year') : t('Previous month')}
            >
              <svg className="icon">
                <use xmlnsXlink="https://www.w3.org/1999/xlink" xlinkHref="#icon-arrow-right" />
              </svg>
            </button>

            {resolution === 'day' && (
              <select
                value={format(date, 'LLLL')}
                onChange={({ target: { value } }) => changeMonth(months.indexOf(value))}
                aria-label={t('Month')}
              >
                {months.map((option: string) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            )}

            {resolution !== 'year' && (
              <select
                value={format(date, 'yyyy')}
                onChange={({ target: { value } }) => changeYear(value)}
                aria-label={t('Year')}
              >
                {years.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            )}

            {resolution === 'year' && <span>{format(selected, 'yyyy')}</span>}

            <button
              onClick={resolution !== 'day' ? increaseYear : increaseMonth}
              disabled={resolution !== 'day' ? nextYearButtonDisabled : nextMonthButtonDisabled}
              aria-label={resolution !== 'day' ? t('Next year') : t('Next month')}
            >
              <svg className="icon">
                <use xmlnsXlink="https://www.w3.org/1999/xlink" xlinkHref="#icon-arrow-right" />
              </svg>
            </button>
          </div>
        )}
      />
    </div>
  );
};

export default Datepicker;
