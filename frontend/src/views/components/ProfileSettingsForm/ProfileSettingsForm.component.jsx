import React from 'react';
import cx from 'classnames';
import { Form, Field } from 'redux-form';
import { T } from '@transifex/react';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';

const ProfileSettingsForm = ({ user, handleSubmit, submitting }) => (
  <Form onSubmit={handleSubmit}>
    <Field component={FormInput} type="email" name="email" label={<T _str="Email" />} autoFocus />

    {!!user.unconfirmed && (
      <div>
        <T _str="Currently waiting confirmation for: {email}" email={user.email} />
      </div>
    )}

    <Field
      component={FormInput}
      type="password"
      name="password"
      label={
        <span>
          <T
            _str="Password{leave_it_blank}"
            _comment="Password<em>(leave blank if you don't want to change it)</em>"
            leave_it_blank={
              <em>
                <T
                  _str="(leave blank if you don't want to change it)"
                  _comment="Password<em>(leave blank if you don't want to change it)</em>"
                />
              </em>
            }
          />
        </span>
      }
      autoComplete="off"
    />

    <Field
      component={FormInput}
      type="password"
      name="password_confirmation"
      label={<T _str="Password confirmation" />}
      autoComplete="off"
    />

    <Field
      component={FormInput}
      type="password"
      name="current_password"
      label={
        <span>
          <T
            _str="Current password
            {we_need_your_password}"
            _comment="Current password<em>(we need your current password to confirm your changes)</em>"
            we_need_your_password={
              <em>
                <T
                  _str="(we need your current password to confirm your changes)"
                  _comment="Current password<em>(we need your current password to confirm your changes)</em>"
                />
              </em>
            }
          />
        </span>
      }
    />

    <Loader loading={submitting} />

    <div className="actions">
      <input
        className={cx('btn-submit', { 'is-loading': submitting })}
        type="submit"
        name="commit"
        value={<T _str="Update" />}
        disabled={submitting}
      />
    </div>
  </Form>
);

export default ProfileSettingsForm;
