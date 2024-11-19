import { Example } from "./Example";

import styles from "./Example.module.css";

export type ExampleModel = {
    text: string;
    value: string;
};

const EXAMPLES: ExampleModel[] = [
    {
        text: "Which baseball players were born in the 1980s?",
        value: "Which baseball players were born in the 1980s?"
    },
    { text: "which players were in the 1933 all-star game?", value: "which players were in the 1933 all-star game?" },
    { text: "What is the name of the White Sox stadium in 2015?", value: "What is the name of the White Sox stadium in 2015?" },
    { text: "What about the Cubs?", value: "What about the Cubs?" }
];

interface Props {
    onExampleClicked: (value: string) => void;
}

export const ExampleList = ({ onExampleClicked }: Props) => {
    return (
        <ul className={styles.examplesNavList}>
            {EXAMPLES.map((x, i) => (
                <li key={i}>
                    <Example text={x.text} value={x.value} onClick={onExampleClicked} />
                </li>
            ))}
        </ul>
    );
};
