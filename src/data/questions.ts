export interface Question {
  question: string;
  options: string[];
  correctIndex: number;
  image?: string;
  points?: number;
}
// Helper: deterministic index from username
const getSeededIndex = (seed: string, poolSize: number, salt: string) => {
  let hash = 0;
  const str = seed + salt;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash) % poolSize;
};

// ===== ROUND 1 =====

// Q1 pool: Logical Reasoning (9 questions — each player gets 1)
const logicalReasoningPool: Question[] = [
  {
    question: "Number Series: 3, 7, 15, 31, 63, ___",
    options: ["95", "127", "124", "111"],
    correctIndex: 1,
  },
  {
    question: "Number Series: 1, 4, 10, 22, 46, ___",
    options: ["92", "88", "94", "90"],
    correctIndex: 2,
  },
  {
    question: "Alphabet Pattern: B, E, I, N, T, ___",
    options: ["X", "Y", "A", "Z"],
    correctIndex: 2,
  },
  {
    question: "Coding-Decoding: If ROAD = URDG, then BOOK = ?",
    options: ["CQQM", "ERRN", "DRRN", "EQQN"],
    correctIndex: 1,
  },
  {
    question: "Direction Sense: A person walks 15m North, then 10m East, then 15m South. Where is he from the starting point?",
    options: ["15m East", "10m East", "10m West", "15m North"],
    correctIndex: 1,
  },
  {
    question: "Blood Relation: Pointing to a woman, Ramesh said, 'She is the daughter of my grandfather's only son.' How is the woman related to Ramesh?",
    options: ["Cousin", "Aunt", "Sister", "Mother"],
    correctIndex: 2,
  },
  {
    question: "Statement & Conclusion: All engineers are graduates. Some graduates are unemployed. Conclusion: Some engineers are unemployed.",
    options: ["Definitely true", "Definitely false", "Cannot be determined", "None"],
    correctIndex: 2,
  },
  {
    question: "Logical Puzzle: If All A are B and All B are C, which is true?",
    options: ["All C are A", "All A are C", "Some C are A", "None"],
    correctIndex: 1,
  },
  {
    question: "Missing Term: 2, 6, 7, 21, 22, 66, ___",
    options: ["198", "68", "67", "132"],
    correctIndex: 2,
  },
];

// Q2 pool: Verbal Reasoning (10 questions — each player gets 1)
const verbalReasoningPool: Question[] = [
  {
    question: "Odd One Out: Pen, Pencil, Eraser, Notebook",
    options: ["Pen", "Pencil", "Eraser", "Notebook"],
    correctIndex: 2,
  },
  {
    question: "Odd One Out: January, March, May, July, September",
    options: ["January", "May", "July", "September"],
    correctIndex: 3,
  },
  {
    question: "\"Once in a blue moon\" means:",
    options: ["Very often", "Very rarely", "At night", "Twice a month"],
    correctIndex: 1,
  },
  {
    question: "\"Under the weather\" means:",
    options: ["Feeling sick", "Standing in rain", "Feeling happy", "Very busy"],
    correctIndex: 0,
  },
  {
    question: "Antonym of \"Optimistic\":",
    options: ["Positive", "Cheerful", "Pessimistic", "Hopeful"],
    correctIndex: 2,
  },
  {
    question: "Antonym of \"Generous\":",
    options: ["Kind", "Selfish", "Friendly", "Helpful"],
    correctIndex: 1,
  },
  {
    question: "Synonym of \"Reluctant\":",
    options: ["Willing", "Angry", "Unwilling", "Confident"],
    correctIndex: 2,
  },
  {
    question: "Synonym of \"Ancient\":",
    options: ["Modern", "Old", "Future", "Young"],
    correctIndex: 1,
  },
  {
    question: "___ Earth revolves around ___ Sun.",
    options: ["The, the", "A, the", "The, a", "No article, the"],
    correctIndex: 0,
  },
  {
    question: "He has ___ MBA degree.",
    options: ["a", "an", "the", "no article"],
    correctIndex: 1,
  },
];

// Q3 pool: Aptitude (12 questions — each player gets 1)
const aptitudePool: Question[] = [
  { question: "25% of 200 = ?", options: ["25", "40", "50", "75"], correctIndex: 2 },
  { question: "15 + 5 × 2 = ?", options: ["40", "25", "30", "20"], correctIndex: 1 },
  { question: "A train runs at 50 km/hr. Distance covered in 2 hours?", options: ["100 km", "120 km", "80 km", "150 km"], correctIndex: 0 },
  { question: "0.5 × 80 = ?", options: ["20", "30", "40", "50"], correctIndex: 2 },
  { question: "If today is Thursday, what day after 30 days?", options: ["Sunday", "Tuesday", "Monday", "Saturday"], correctIndex: 3 },
  { question: "What is 45 ÷ 5 × 2?", options: ["9", "15", "18", "20"], correctIndex: 2 },
  { question: "Square of 15 = ?", options: ["225", "215", "205", "235"], correctIndex: 0 },
  { question: "Find the HCF of 36 and 48.", options: ["6", "12", "18", "24"], correctIndex: 1 },
  { question: "A car travels 60 km in 2 hours. What is its speed?", options: ["30 km/hr", "40 km/hr", "45 km/hr", "50 km/hr"], correctIndex: 0 },
  { question: "What is the square of 18?", options: ["324", "328", "320", "340"], correctIndex: 0 },
  { question: "If 5 workers complete a work in 10 days, how many days will 10 workers take?", options: ["2", "4", "5", "8"], correctIndex: 2 },
  { question: "A train travels 60 km in 40 minutes. How far will it travel in 1.5 hours?", options: ["120 km", "135 km", "150 km", "90 km"], correctIndex: 1 },
];

// Get Round 1 questions: all 3 randomized from pools
export const getRound1Questions = (username: string): Question[] => {
  const q1 = logicalReasoningPool[getSeededIndex(username, logicalReasoningPool.length, "logical")];
  const q2 = verbalReasoningPool[getSeededIndex(username, verbalReasoningPool.length, "verbal")];
  const q3 = aptitudePool[getSeededIndex(username, aptitudePool.length, "aptitude")];
  return [q1, q2, q3];
};

// Fallback
export const round1Questions: Question[] = [logicalReasoningPool[0], verbalReasoningPool[0], aptitudePool[0]];

// ===== ROUND 2: Tech Riddles (3 questions from pool, 15pts each) =====
const techRiddlePool: Question[] = [
  { question: "I am the brain of the computer.", options: ["RAM", "Hard Disk", "CPU", "Monitor"], correctIndex: 2 },
  { question: "I store temporary data and forget everything when power is off.", options: ["ROM", "RAM", "SSD", "Hard Disk"], correctIndex: 1 },
  { question: "I connect your computer to the internet wirelessly.", options: ["CPU", "Router", "Monitor", "Speaker"], correctIndex: 1 },
  { question: "I fix errors in your program.", options: ["Compiler", "Debugger", "Scanner", "Printer"], correctIndex: 1 },
  { question: "I am not hardware, I am not software, but I help hardware and software communicate.", options: ["Keyboard", "Operating System", "Mouse", "Monitor"], correctIndex: 1 },
  { question: "I send data in small packets across the internet to reach websites.", options: ["Browser", "HTTP", "RAM", "USB"], correctIndex: 1 },
  { question: "I am a tiny storage inside the CPU that stores frequently used data to make things faster.", options: ["Cache Memory", "Hard Disk", "ROM", "Pen Drive"], correctIndex: 0 },
  { question: "I allow multiple computers to share files and resources in a building.", options: ["LAN", "RAM", "CPU", "SSD"], correctIndex: 0 },
  { question: "I am used to copy data from one device to another using a small portable device.", options: ["RAM", "USB / Pen Drive", "CPU", "Cache"], correctIndex: 1 },
  { question: "I am used to organize data in rows and columns in programming.", options: ["Stack", "Array", "Queue", "Tree"], correctIndex: 1 },
  { question: "I temporarily store frequently used data to make processing faster.", options: ["Hard Disk", "Cache Memory", "Monitor", "Printer"], correctIndex: 1 },
  { question: "I am a special character that ends most Java statements.", options: [":", ".", ";", ","], correctIndex: 2 },
];

// Pick 3 unique tech riddles per user
export const getRound2Questions = (username: string): Question[] => {
  const idx1 = getSeededIndex(username, techRiddlePool.length, "tech1");
  let idx2 = getSeededIndex(username, techRiddlePool.length, "tech2");
  while (idx2 === idx1) idx2 = (idx2 + 1) % techRiddlePool.length;
  let idx3 = getSeededIndex(username, techRiddlePool.length, "tech3");
  while (idx3 === idx1 || idx3 === idx2) idx3 = (idx3 + 1) % techRiddlePool.length;
  return [techRiddlePool[idx1], techRiddlePool[idx2], techRiddlePool[idx3]];
};

// Fallback
export const round2Questions: Question[] = [techRiddlePool[0], techRiddlePool[1], techRiddlePool[2]];

// ===== ROUND 3: Rapid Fire — 5 categories, 10 questions each, 1 per player =====

// Category 1: Fill in the Blanks (10)
const fillBlanksPool: Question[] = [
  { question: "CPU stands for:", options: ["Central Program Unit", "Central Processing Unit", "Control Processing Unit", "Computer Processing Unit"], correctIndex: 1 },
  { question: "The extension of a Java file is:", options: [".py", ".java", ".class", ".js"], correctIndex: 1 },
  { question: "In a stack, deletion operation is called:", options: ["Push", "Enqueue", "Pop", "Remove"], correctIndex: 2 },
  { question: "Which symbol is used for single-line comment in Java?", options: ["#", "//", "/*", "--"], correctIndex: 1 },
  { question: "SQL is mainly used to:", options: ["Design websites", "Style pages", "Manage databases", "Compile code"], correctIndex: 2 },
  { question: "Which data structure uses FIFO?", options: ["Stack", "Queue", "Tree", "Graph"], correctIndex: 1 },
  { question: "Which memory is fastest?", options: ["Hard Disk", "RAM", "Cache", "ROM"], correctIndex: 2 },
  { question: "HTML is used to create:", options: ["Styling", "Structure", "Logic", "Database"], correctIndex: 1 },
  { question: "Binary search time complexity:", options: ["O(n)", "O(log n)", "O(n²)", "O(1)"], correctIndex: 1 },
  { question: "A function calling itself is:", options: ["Loop", "Recursion", "Iteration", "Compilation"], correctIndex: 1 },
];

// Category 2: Match the Following (10)
const matchPool: Question[] = [
  { question: "Stack → ?", options: ["FIFO", "LIFO", "Random", "Sorted"], correctIndex: 1 },
  { question: "Queue → ?", options: ["LIFO", "Priority", "FIFO", "Stack"], correctIndex: 2 },
  { question: "CSS → ?", options: ["Programming", "Styling", "Database", "Compiler"], correctIndex: 1 },
  { question: "DNS → ?", options: ["Storage", "Domain to IP conversion", "Virus scan", "Sorting"], correctIndex: 1 },
  { question: "RAM → ?", options: ["Permanent memory", "Temporary memory", "Processor", "Compiler"], correctIndex: 1 },
  { question: "HTTP → ?", options: ["Web protocol", "Memory type", "Algorithm", "Sorting method"], correctIndex: 0 },
  { question: "Java → ?", options: ["Database", "Markup Language", "Programming Language", "Styling Tool"], correctIndex: 2 },
  { question: "ROM → ?", options: ["Temporary memory", "Permanent memory", "Cache", "Input device"], correctIndex: 1 },
  { question: "OS → ?", options: ["Manages hardware", "Designs websites", "Prints files", "Stores passwords"], correctIndex: 0 },
  { question: "Array → ?", options: ["Dynamic pointer structure", "Fixed-size collection", "Sorting method", "Loop"], correctIndex: 1 },
];

// Category 3: Programming Keyword Identification (10)
const keywordPool: Question[] = [
  { question: "`def` belongs to:", options: ["Java", "Python", "C", "C++"], correctIndex: 1 },
  { question: "`cout` belongs to:", options: ["Java", "C", "C++", "Python"], correctIndex: 2 },
  { question: "`System.out.println()` belongs to:", options: ["Python", "C", "Java", "JavaScript"], correctIndex: 2 },
  { question: "`console.log()` belongs to:", options: ["JavaScript", "Java", "C", "Python"], correctIndex: 0 },
  { question: "`#include<stdio.h>` belongs to:", options: ["C", "Python", "Java", "SQL"], correctIndex: 0 },
  { question: "`elif` is used in:", options: ["C", "Java", "Python", "C++"], correctIndex: 2 },
  { question: "`var` is common in:", options: ["JavaScript", "C", "SQL", "HTML"], correctIndex: 0 },
  { question: "`public static void main` belongs to:", options: ["C++", "Java", "Python", "JS"], correctIndex: 1 },
  { question: "`printf()` belongs to:", options: ["Java", "Python", "C", "CSS"], correctIndex: 2 },
  { question: "`import java.util.*;` belongs to:", options: ["C", "Python", "Java", "SQL"], correctIndex: 2 },
];

// Category 4: True / False (10)
const trueFalsePool: Question[] = [
  { question: "Binary search works on unsorted arrays.", options: ["True", "False"], correctIndex: 1 },
  { question: "Stack uses only one pointer called 'top'.", options: ["True", "False"], correctIndex: 0 },
  { question: "Java allows multiple inheritance using classes.", options: ["True", "False"], correctIndex: 1 },
  { question: "Cache memory is slower than RAM.", options: ["True", "False"], correctIndex: 1 },
  { question: "An array index in Java starts at 1.", options: ["True", "False"], correctIndex: 1 },
  { question: "A queue can be implemented using arrays.", options: ["True", "False"], correctIndex: 0 },
  { question: "HTML can execute logic like loops.", options: ["True", "False"], correctIndex: 1 },
  { question: "`==` checks value equality in Java.", options: ["True", "False"], correctIndex: 0 },
  { question: "O(1) means constant time.", options: ["True", "False"], correctIndex: 0 },
  { question: "Recursion always uses stack memory.", options: ["True", "False"], correctIndex: 0 },
];

// Category 5: Output Prediction (10)
const outputPool: Question[] = [
  { question: "int a=5, b=3; System.out.println(a*b+a);", options: ["20", "15", "18", "25"], correctIndex: 0 },
  { question: "int x=10; System.out.println(x++ + ++x);", options: ["21", "22", "20", "23"], correctIndex: 1 },
  { question: "System.out.println(5 > 3 && 2 < 1);", options: ["true", "false", "1", "error"], correctIndex: 1 },
  { question: "int a=4; System.out.println(a==4 ? 10 : 20);", options: ["4", "10", "20", "error"], correctIndex: 1 },
  { question: 'System.out.println("Hello" + 5 + 5);', options: ["Hello10", "Hello55", "10Hello", "Error"], correctIndex: 1 },
  { question: "int a=6; System.out.println(a % 4);", options: ["1", "2", "3", "4"], correctIndex: 1 },
  { question: "int a=3; a*=2; System.out.println(a);", options: ["3", "5", "6", "9"], correctIndex: 2 },
  { question: "System.out.println(10 / 4.0);", options: ["2", "2.5", "3", "2.0"], correctIndex: 1 },
  { question: "boolean x=false; System.out.println(!x);", options: ["true", "false", "error", "0"], correctIndex: 0 },
  { question: "int a=5; System.out.println(a--);", options: ["4", "5", "6", "error"], correctIndex: 1 },
];

// Pick 1 from each category per user (5 questions total)
export const getRound3Questions = (username: string): Question[] => {
  return [
    fillBlanksPool[getSeededIndex(username, fillBlanksPool.length, "fill")],
    matchPool[getSeededIndex(username, matchPool.length, "match")],
    keywordPool[getSeededIndex(username, keywordPool.length, "keyword")],
    trueFalsePool[getSeededIndex(username, trueFalsePool.length, "tf")],
    outputPool[getSeededIndex(username, outputPool.length, "output")],
  ];
};

// Fallback
export const round3Questions: Question[] = [fillBlanksPool[0], matchPool[0], keywordPool[0], trueFalsePool[0], outputPool[0]];

// ===== ROUND 4: Final DSA Challenge — 10-question pool, 2 per player =====
const dsaPool: Question[] = [
  { question: "Which data structure is most suitable for implementing Undo/Redo operations?", options: ["Queue", "Stack", "Linked List", "Tree"], correctIndex: 1, points: 15 },
  { question: "In a Binary Search Tree (BST), where are smaller values placed?", options: ["Right subtree", "Left subtree", "Randomly", "Anywhere"], correctIndex: 1, points: 15 },
  { question: "Which traversal visits nodes in the order: Root → Left → Right?", options: ["Inorder", "Postorder", "Preorder", "Level Order"], correctIndex: 2, points: 15 },
  { question: "In a queue, if the queue is empty and you try to delete, it is called:", options: ["Overflow", "Underflow", "Push", "Collision"], correctIndex: 1, points: 15 },
  { question: "Which data structure is used to implement recursion internally?", options: ["Queue", "Stack", "Array", "Graph"], correctIndex: 1, points: 20 },
  { question: "In a circular queue, the condition for full queue is:", options: ["rear == front", "(rear + 1) % size == front", "front == -1", "rear == -1"], correctIndex: 1, points: 20 },
  { question: "Which data structure is best to represent a hierarchical structure?", options: ["Array", "Stack", "Tree", "Queue"], correctIndex: 2, points: 15 },
  { question: "A graph with no cycles is called:", options: ["Complete Graph", "Directed Graph", "Tree", "Weighted Graph"], correctIndex: 2, points: 20 },
  { question: "In a doubly linked list, each node contains:", options: ["Only data", "Data and one pointer", "Data and two pointers", "Two data values"], correctIndex: 2, points: 20 },
  { question: "Which data structure is best for implementing priority-based processing (like CPU scheduling)?", options: ["Stack", "Queue", "Priority Queue", "Linked List"], correctIndex: 2, points: 20 },
];

// Pick 2 unique DSA questions per user
export const getRound4Questions = (username: string): Question[] => {
  const idx1 = getSeededIndex(username, dsaPool.length, "dsa1");
  let idx2 = getSeededIndex(username, dsaPool.length, "dsa2");
  while (idx2 === idx1) idx2 = (idx2 + 1) % dsaPool.length;
  return [dsaPool[idx1], dsaPool[idx2]];
};

// Fallback
export const round4Questions: Question[] = [dsaPool[0], dsaPool[1]];

// ⚠️ UPDATE THESE before the event! Write location hints specific to YOUR campus/venue.
// Each hint leads players to the next QR code location.
export const locationHints = [
  "📍 [HINT FOR ROUND 2 LOCATION] — Write a riddle or clue leading to where you'll place QR code #2.",
  "📍 [HINT FOR ROUND 3 LOCATION] — Write a riddle or clue leading to where you'll place QR code #3.",
  "📍 [HINT FOR ROUND 4 LOCATION] — Write a riddle or clue leading to where you'll place QR code #4.",
  "📍 [HINT FOR FINAL LOCATION] — Write a riddle or clue for the last checkpoint.",
];

// ⚠️ CHANGE THESE before the event! These must match the QR codes you print.
// After changing, run: node scripts/generate_qrs.js to regenerate QR code images.
export const roundPasswords: Record<number, string> = {
  1: "glitch_protocol_start",
  2: "echo_silence_break",
  3: "css_style_master",
  4: "binary_search_log_n",
};
