import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import { WebsiteSchema } from 'state/modules/feedback';

import { asyncValidate } from 'views/utils/asyncValidate';

import Website from './Website.component';

const mapStateToProps = (state) => ({
  formValues: state['form']['Feedback']?.values,
});

const withConnect = connect(mapStateToProps);

const withForm = reduxForm({
  form: 'Feedback',
  destroyOnUnmount: false,
  forceUnregisterOnUnmount: true,
  asyncValidate: asyncValidate(WebsiteSchema),
});

export default compose(withConnect, withForm)(Website);
