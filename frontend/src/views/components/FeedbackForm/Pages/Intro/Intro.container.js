import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import { IntroSchema } from 'state/modules/feedback';

import { asyncValidate } from 'views/utils/asyncValidate';

import Intro from './Intro.component';

const mapStateToProps = (state) => ({
  formValues: state['form']['Feedback']?.values,
});

const withConnect = connect(mapStateToProps);

const withForm = reduxForm({
  form: 'Feedback',
  destroyOnUnmount: false,
  forceUnregisterOnUnmount: true,
  asyncValidate: asyncValidate(IntroSchema),
});

export default compose(withConnect, withForm)(Intro);
