import { post } from '../../utils/api';

const URL_FEEDBACK = '/feedbacks';

export const submitFeedback = (values) =>
  post(URL_FEEDBACK, { data: values }).then((response) => response.data);
