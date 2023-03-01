import React from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';
import Loader from '@shared/Loader';

import { toggle as toggleGroup } from '@modules/layer_groups';
import { clickable } from '@utilities';

import Layer from './Layer';
import Basemaps from './Basemaps';

const enhance = connect(
  null,
  (dispatch, ownProps) => ({
    toggleActive: () => dispatch(toggleGroup(ownProps.id)),
  }),
);

let Subgroup = ({ toggleActive, id, name, active, layers }) => (
  <li className="subgroup">
    <div
      className={cx('m-layers-list-header', { 'is-active': !!active })}
      {...clickable(toggleActive)}
    >
      <div className="header-title ">{name}</div>
      <div
        id={`categoryHeader_${id}`}
        className="header-switch m-form-input--switch"
      />
    </div>

    {active && layers && (
      <ul className={cx('m-layers-list-panel', { 'is-active': !!active })}>
        {layers.map(layer => (
          <Layer key={layer.id} {...layer} />
        ))}
      </ul>
    )}
  </li>
);

Subgroup = enhance(Subgroup);

let Category = ({ toggleActive, id, name, active, layers, subcategory }) => (
  <li key={id} className="category">
    <div
      className={cx('m-layers-list-header', {
        'is-active': !!active,
      })}
      {...clickable(toggleActive)}
    >
      <div className="header-title">{name}</div>
      <div
        id={`categoryHeader_${id}`}
        className="header-switch m-form-input--switch"
      />
    </div>

    {active && layers && (
      <ul
        className={cx('m-layers-list-panel', {
          'is-active': !!active,
        })}
      >
        {layers.map(layer => (
          <Layer key={layer.id} LayerGroupName={name} {...layer} />
        ))}

        {subcategory.map(subcat => (
          <Subcategory key={subcat.id} {...subcat} />
        ))}
      </ul>
    )}
  </li>
);

Category = enhance(Category);

let Subcategory = ({ toggleActive, id, name, active, layers, subgroup }) => (
  <li className="subcategory">
    <div
      className={cx('m-layers-list-header', { 'is-active': !!active })}
      {...clickable(toggleActive)}
    >
      <div className="header-title">{name}</div>
      <div
        id={`categoryHeader_${id}`}
        className="header-switch m-form-input--switch"
      />
    </div>

    {active && layers && (
      <ul className={cx('m-layers-list-panel', { 'is-active': !!active })}>
        {layers.map(layer => (
          <Layer key={layer.id} {...layer} withDashboardOrder />
        ))}
        {subgroup.map(s_group => (
          <Subgroup key={s_group.id} {...s_group} />
        ))}
      </ul>
    )}
  </li>
);

Subcategory = enhance(Subcategory);

let Group = ({ toggleActive, id, slug, name, active, layers, categories }) => (
  <li key={id} className="group" data-slug={slug}>
    <div
      className={cx('m-layers-list-header', { 'is-active': !!active })}
      {...clickable(toggleActive)}
    >
      <div className="header-title theme-color">{name}</div>
    </div>
    {active && layers && (
      <ul className={cx('m-layers-list-panel', { 'is-active': !!active })}>
        {layers.map(({ dashboard_order, ...layer }) => (
          <Layer key={layer.id} {...layer} withDashboardOrder />
        ))}

        {categories.map(cat => (
          <Category key={cat.id} {...cat} />
        ))}
      </ul>
    )}
  </li>
);

Group = enhance(Group);

const LayersList = ({ groups, loading }) => (
  <>
    <Loader loading={loading} />

    <ul>
      {groups.map(group => (
        <Group key={group.id} {...group} />
      ))}

      <Basemaps />
    </ul>
  </>
);

export default LayersList;
