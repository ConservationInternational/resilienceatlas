import type { components } from '@reactour/tour';

type BadgeProps = (typeof components)['Badge'];

const MapTourBadge: BadgeProps = ({ children }) => <div className="map-tour-badge">{children}</div>;

export default MapTourBadge;
