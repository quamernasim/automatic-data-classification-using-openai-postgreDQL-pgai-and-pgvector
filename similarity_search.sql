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



CREATE EXTENSION IF NOT EXISTS vectorscale;



-- Create the `product_reviews_embedding` table
CREATE TABLE product_reviews_embedding (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    embedding VECTOR(1536)               -- The vector type comes from the pgvector extension
);



-- Create an index on the `embedding` column using `diskann` for efficient vector search
CREATE INDEX product_reviews_embedding_idx ON product_reviews_embedding
USING diskann (embedding);



-- Insert embeddings into the `product_reviews_embedding` table
INSERT INTO product_reviews_embedding (customer_id, embedding)
SELECT
    customer_id,
    openai_embed('text-embedding-3-small', format('short_review: %s review: %s', short_review, review)) AS embedding
FROM product_reviews;



-- Create the `query_embeddings` table
CREATE TABLE query_embeddings (
    id INT NOT NULL PRIMARY KEY,  -- Unique identifier for each query
    query TEXT,                   -- The query text
    embedding VECTOR(1536)        -- The embedding vector of 1536 dimensions
)
;



-- Insert example queries along with their embeddings into the `query_embeddings` table
INSERT INTO query_embeddings (id, query, embedding)
VALUES
(1, 'which of these are positive reviews?', openai_embed('text-embedding-3-small', 'which of these are positive reviews?')),
(2, 'which of these are negative reviews?', openai_embed('text-embedding-3-small', 'which of these are negative reviews?')),
(3, 'which of these are neutral reviews?', openai_embed('text-embedding-3-small', 'which of these are neutral reviews?'))
;



-- Retrieve the top 10 product reviews most similar to the query "which of these are positive reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 1 -- Using the embedding of the third query: "which of these are positive reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews



-- Retrieve the top 10 product reviews most similar to the query "which of these are negative reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 2 -- Using the embedding of the third query: "which of these are negative reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews



-- Retrieve the top 10 product reviews most similar to the query "which of these are neutral reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 3 -- Using the embedding of the third query: "which of these are neutral reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews