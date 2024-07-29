https://github.com/timescale/pgai?tab=readme-ov-file#use-a-pre-built-docker-container
https://docs.timescale.com/self-hosted/latest/install/installation-docker/
https://www.timescale.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows/
sudo apt update
sudo apt install postgresql-client
psql --version
docker pull timescale/timescaledb-ha:pg16
docker run -d --name timescaledb -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb-ha:pg16
\dx
CREATE EXTENSION IF NOT EXISTS ai CASCADE;
\dx






-- a table for storing git commit history
create table product_reviews
( customer_id int not null primary key
, date timestamptz
, product text
, short_review text
, review text
);

\dt




insert into product_reviews (customer_id, date, product, short_review, review) values
  ('1', '2022-01-01', 'laptop', 'Great!', 'Great laptop, very fast and reliable.')
, ('2', '2022-01-02', 'laptop', 'Good', 'Good laptop, but the battery life could be better.')
, ('3', '2022-01-03', 'laptop', 'Worst ever', 'This is the worst laptop I have ever used.')
, ('4', '2022-01-04', 'laptop', 'Not bad', 'Not bad, but the screen is a bit small.')
, ('5', '2022-01-05', 'phone', 'Excellent', 'Excellent phone, great camera and battery life.')
, ('6', '2022-01-06', 'phone', 'Decent', 'Decent phone, but the screen is not as good as I expected.')
, ('7', '2022-01-07', 'phone', 'Poor', 'Poor phone, battery life is terrible and camera quality is not good.')
, ('8', '2022-01-08', 'tablet', 'Awesome', 'Awesome tablet, very fast and responsive.')
, ('9', '2022-01-09', 'tablet', 'Satisfactory', 'Satisfactory tablet, but the screen resolution could be better.')
, ('10', '2022-01-10', 'tablet', 'Disappointing', 'Disappointing tablet, slow performance and battery drains quickly.')
;



create table product_reviews_embedding
( customer_id int not null primary key
, embedding vector(220) -- the vector type comes from the pgvector extension
);


export OPENAI_API_KEY="{API_KEY}"


PGOPTIONS="-c ai.openai_api_key=$OPENAI_API_KEY" psql -d "postgres://postgres:password@localhost/postgres"
psql -d "postgres://postgres:password@localhost/postgres" -v openai_api_key=$OPENAI_API_KEY

select set_config('ai.openai_api_key', '{API_KEY}', false) is not null as set_config;


insert into product_reviews_embedding (customer_id, embedding)
select
  customer_id
, openai_embed( 'text-embedding-3-small', format('short_review: %s review: %s', short_review, review)) as embedding
from product_reviews
;

      
\copy (SELECT * FROM product_reviews_embedding LIMIT 1) TO '/home/quamer23nasim38/automatic-data-classification-using-openai-postgreDQL-pgai-and-pgvector/file.csv' CSV HEADER;



create table product_reviews_classification
( customer_id int not null primary key
, review_type text
);
  




WITH formatted_reviews AS (
    SELECT 
        customer_id,
        format(
            E'%s %s\nshort_review: %s\nreview: %s\n\t',
            short_review, review, short_review, review
        ) AS product_final_review
    FROM product_reviews
),
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
                            E'Classify the following product review into positive, negative, or neutral categories:\n\n',
                            string_agg(x.product_final_review, E'\n\n')
                        )
                    )
                )
            )->'choices'->0->'message'->>'content' AS result
        FROM formatted_reviews x
        GROUP BY customer_id
    ) subquery
)
INSERT INTO product_reviews_classification (customer_id, review_type)
SELECT customer_id, review_type
FROM classified_reviews;




































WITH formatted_reviews AS (
    SELECT 
        customer_id,
        format(
            E'%s %s\nshort_review: %s\nreview: %s\n\t',
            short_review, review, short_review, review
        ) AS product_final_review
    FROM product_reviews
),
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
                            E'Classify the following product review into positive, negative, or neutral categories. You can not output anything except "psotive", "negative", "neutral":\n\n',
                            string_agg(x.product_final_review, E'\n\n')
                        )
                    )
                )
            )->'choices'->0->'message'->>'content' AS result
        FROM formatted_reviews x
        GROUP BY customer_id
    ) subquery
)
UPDATE product_reviews_classification
SET review_type = classified_reviews.review_type
FROM classified_reviews
WHERE product_reviews_classification.customer_id = classified_reviews.customer_id;














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
