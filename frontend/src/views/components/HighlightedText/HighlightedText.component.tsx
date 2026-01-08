type HighlightedTextProps = {
  text: string;
  highlight: string;
};

const HighlightedText: React.FC<HighlightedTextProps> = ({ text, highlight }) => {
  // Split on highlight term and include term into parts, ignore case
  const parts = text.split(new RegExp(`(${highlight})`, 'gi'));
  return (
    <span className="m-highlighted-text">
      {' '}
      {parts.map((part, i) => (
        <span
          key={i}
          className={
            part.toLowerCase() === highlight.toLowerCase() ? 'm-highlighted-text--selected' : null
          }
        >
          {part}
        </span>
      ))}{' '}
    </span>
  );
};

export default HighlightedText;
