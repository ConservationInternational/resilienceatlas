export interface DatepickerProps {
  startDate: Date;
  endDate: Date;
  selected: Date;
  onSelect: (date: Date) => void;
  format?: string;
  resolution: 'day' | 'month' | 'year';
  ariaDescribedBy?: string;
  ariaInvalid?: string;
  ariaLabelledBy?: string;
  ariaRequired?: string;
  id?: string;
  name?: string;
  title?: string;
  disabled?: boolean;
  required?: boolean;
  readOnly?: boolean;
  includeDates?: Date[];
}
