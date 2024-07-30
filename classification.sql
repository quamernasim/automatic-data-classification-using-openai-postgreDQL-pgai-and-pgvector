CREATE EXTENSION IF NOT EXISTS ai CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;



-- Create the `product_reviews` table
CREATE TABLE product_reviews (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    date TIMESTAMPTZ,                     -- Timestamp with timezone for the review date
    product TEXT,                         -- Name of the product being reviewed
    short_review TEXT,                    -- A brief summary of the review
    review TEXT                           -- The detailed review text
)
;



-- Insert sample data into `product_reviews` table
INSERT INTO product_reviews (customer_id, date, product, short_review, review) VALUES
(1, '2022-01-01', 'laptop', 'Great!', 'Great laptop, very fast and reliable.'),
(2, '2022-01-02', 'laptop', 'Good', 'Good laptop, but the battery life could be better.'),
(3, '2022-01-03', 'laptop', 'Worst ever', 'This is the worst laptop I have ever used.'),
(4, '2022-01-04', 'laptop', 'Not bad', 'Not bad, but the screen is a bit small.'),
(5, '2022-01-05', 'phone', 'Excellent', 'Excellent phone, great camera and battery life.'),
(6, '2022-01-06', 'phone', 'Decent', 'Decent phone, but the screen is not as good as I expected.'),
(7, '2022-01-07', 'phone', 'Poor', 'Poor phone, battery life is terrible and camera quality is not good.'),
(8, '2022-01-08', 'tablet', 'Awesome', 'Awesome tablet, very fast and responsive.'),
(9, '2022-01-09', 'tablet', 'Satisfactory', 'Satisfactory tablet, but the screen resolution could be better.'),
(10, '2022-01-10', 'tablet', 'Disappointing', 'Disappointing tablet, slow performance and battery drains quickly.')
;



-- Create the `product_reviews_classification` table
CREATE TABLE product_reviews_classification (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    review_type TEXT                      -- The classification type of the review (e.g., Positive, Negative, Neutral)
)
;



-- Step 1: Format reviews with a structured template
WITH formatted_reviews AS (
    SELECT 
        customer_id,
        format(
            E'%s %s\nshort_review: %s\nreview: %s\n\t',
            short_review, review, short_review, review
        ) AS product_final_review
    FROM product_reviews
),

-- Step 2: Classify reviews using OpenAI and categorize the results
classified_reviews AS (
    SELECT
        customer_id,
        CASE
            WHEN result IN ('positive', 'negative', 'neutral') THEN result
            ELSE 'neutral'
        END AS review_type
    FROM (
        SELECT
            customer_id,
            openai_chat_complete(
                'gpt-4o',
                jsonb_build_array(
                    jsonb_build_object(
                        'role', 'system',
                        'content', 'You are an assistant that classifies product reviews into positive, negative, or neutral categories. You can only output one of these three categories: positive, negative, or neutral.'
                    ),
                    jsonb_build_object(
                        'role', 'user',
                        'content', 
                        concat(
                            E'Classify the following product review into positive, negative, or neutral categories. You cannot output anything except "positive", "negative", "neutral":\n\n',
                            string_agg(x.product_final_review, E'\n\n')
                        )
                    )
                )
            )->'choices'->0->'message'->>'content' AS result
        FROM formatted_reviews x
        GROUP BY customer_id
    ) subquery
)

-- Step 3: Insert classified reviews into the `product_reviews_classification` table
INSERT INTO product_reviews_classification (customer_id, review_type)
SELECT customer_id, review_type
FROM classified_reviews
;



-- Final step: Join the `product_reviews` and `product_reviews_classification` tables to get the classified reviews
SELECT 
    pr.customer_id,
    pr.review,
    prc.review_type
FROM
    product_reviews pr
JOIN
    product_reviews_classification prc
ON
    pr.customer_id = prc.customer_id;